{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE DeriveGeneric             #-}
{-# LANGUAGE NamedFieldPuns #-}

module Generator.Generator where

import Data.Set (Set)
import qualified Data.Set as Set
import Control.Monad.Trans.Class
import Control.Monad.Trans.State.Lazy
import Control.Applicative
import Text.Printf
import Language.Haskell.TH
import Language.Haskell.TH.Syntax (VarStrictType)
import qualified Language.Haskell.TH.Syntax as THS
import Language.Haskell.TH.Quote
import Data.List
import qualified Data.Set as Set
import Data.Int
import Data.Default
import Data.Monoid

import Control.Lens hiding ((<.>))
import Control.Lens.TH

import GHC.Stack
import Debug.Trace
import Control.Exception
import System.FilePath
import Data.DeriveTH
import Data.List.Split
import System.Directory
import Control.Monad
import Data.String.Utils

-- import Generator.Expr (Lit2, Lit5)

derive makeIs ''Dec

----------------------------------

getDecName :: Dec -> Name
getDecName dec = case dec of
    FunD         n _       -> n
    DataD        _ n _ _ _ -> n
    NewtypeD     _ n _ _ _ -> n
    TySynD       n _ _     -> n
    ClassD       _ n _ _ _ -> n
    SigD         n _       -> n
    FamilyD      _ n _ _   -> n
    DataInstD    _ n _ _ _ -> n
    NewtypeInstD _ n _ _ _ -> n
    --TySynInstD   n _ _     -> n
    _                      -> error "This Dec does not have a name!"


getTypeName :: Type -> Name
getTypeName t = case t of
    VarT n  -> n
    ConT n  -> n
    _       -> error $ "Type " ++ show t ++ "has no name!"

----------------------------------

class ArgumentTypes a where
    argumentTypes :: a -> [Type]

instance ArgumentTypes Type where
    argumentTypes functionType = case functionType of
        AppT 
            (AppT ArrowT t) 
            (rhs) 
          -> [t] ++ argumentTypes rhs
        _ -> []


returnedType :: Type -> Type
returnedType functionType | trace ("<<>>" <> show functionType) False = undefined
returnedType functionType = case functionType of
        AppT (AppT ArrowT _) right@(AppT (AppT ArrowT _) _)
            -> returnedType right
        AppT (AppT ArrowT _) ret  
            -> ret
        _   -> error $ "Failed to deduce returned type from " ++ show functionType

-- takes name of function to call and list of arguments names
callWithArgs :: Name -> [Name] -> Exp
callWithArgs fname [] = VarE fname
callWithArgs fname fargs = AppE (callWithArgs fname $ init fargs) (VarE $ last fargs)

----------------------------------

type HeaderSource = String

type ImplementationSource = String

type CppFormattedCode = (HeaderSource, ImplementationSource)

class CppFormattablePart a where
    format :: a -> String

class CppFormattable a  where
    formatCpp :: a -> CppFormattedCode

class TypesDependencies a where
    symbolDependencies :: a -> Set Name

class HsTyped a where
    hsType :: a -> Type

class HsNamed a where
    hsName :: a -> Name

instance HsNamed Con where
    hsName con = case con of
        NormalC n _ -> n
        RecC n _ -> n
        InfixC _ n _ -> n
        ForallC _ _ con -> hsName con

data CppArg = CppArg
    { argName :: String
    , argType :: String
    }
    deriving (Show)

makeLenses ''CppArg

instance CppFormattablePart CppArg where
    format arg = argType arg <> " " <> argName arg

data CppQualifier = ConstQualifier | VolatileQualifier | PureVirtualQualifier | OverrideQualifier
                    deriving (Show, Eq)

makeLenses ''CppQualifier
derive makeIs ''CppQualifier

instance CppFormattablePart CppQualifier where
    format ConstQualifier = " const"
    format VolatileQualifier = " volatile"
    format OverrideQualifier = " override"
    format PureVirtualQualifier = " = 0"

type CppQualifiers = [CppQualifier]

instance CppFormattablePart CppQualifiers where
    format qualifiers = intercalate " " $ (map format qualifiers)


data CppStorage = Usual | Static | Virtual
    deriving (Show)

makeLenses ''CppQualifier

instance CppFormattablePart CppStorage where
    format Usual = ""
    format Static = "static "
    format Virtual = "virtual "

data CppFunction = CppFunction
    { name :: String
    , returnType :: String
    , args :: [CppArg]
    , body :: String
    }
    deriving (Show)

makeLenses ''CppFunction

formatArgsList :: [CppArg] -> String
formatArgsList args = "(" <> Data.List.intercalate ", " (map format args) <> ")"

formatSignature :: CppFunction -> String
formatSignature (CppFunction name ret args _) = formatArgsList args

data CppMethod = CppMethod
    { function :: CppFunction
    , qualifiers :: CppQualifiers
    , storage :: CppStorage
    }
    deriving (Show)

makeLenses ''CppMethod

isPureVirtual :: CppMethod -> Bool
isPureVirtual method = any isPureVirtualQualifier $ qualifiers method

data CppFieldSource = CppFieldSourceRec VarStrictType
                    | CppFieldSourceNormal THS.StrictType
    deriving (Show, Eq)

makeLenses ''CppFieldSource

data CppField = CppField
    { fieldName :: String
    , fieldType :: String
    , source :: CppFieldSource
    }
    deriving (Show, Eq)
makeLenses ''CppField


data CppAccess = Protected | Public | Private
    deriving (Show)
makeLenses ''CppAccess

data CppDerive = CppDerive
    { baseName :: String
    , isVirtual :: Bool
    , access :: CppAccess
    }
    deriving (Show)
makeLenses ''CppDerive

data CppEnum = CppEnum
    { _enumName :: String
    , _enumElems :: [String]
    }
    deriving (Show)
makeLenses ''CppEnum

data CppClass = CppClass
    { _className :: String
    , _classFields :: [CppField]
    , _classMethods :: [CppMethod]
    , _classBases :: [CppDerive]
    , _classTemplateParams :: [String]
    , _classEnums :: [CppEnum]
    }
    deriving (Show)
makeLenses ''CppClass


data CppTypedef  = CppTypedef
    { introducedType :: String
    , baseType :: String
    , _typedefTmpl :: [String]
    }
    deriving (Show)

makeLenses ''CppTypedef


data CppWrapperType = CppWrapperTypeClass Dec | CppWrapperAlias Dec

derive makeIs ''CppWrapperType

data CppWrapper = Name Info CppWrapperType

data CppInclude = CppSystemInclude String | CppLocalInclude String
    deriving (Eq, Ord, Show)



instance CppFormattablePart CppEnum where
    format (CppEnum name elems) =
        let fmt = "enum %s { %s };"
        in printf fmt (name) (intercalate ", " elems)

instance CppFormattablePart [CppEnum] where
    format enums = intercalate "\n" (format <$> enums)

--data CppInclude = CppSystemInclude String | CppLocalInclude String
--instance CppFormattable CppInclude where
--    formatCpp (CppSystemInclude path) = (printf "#include <%s>" path, "")
--    formatCpp (CppLocalInclude path) = (printf "#include \"%s\"" path, "")

unixifyPath :: String -> String
unixifyPath = replace "\\" "/"

includeText :: CppInclude -> String
includeText (CppSystemInclude path) = printf "#include <%s>" $ unixifyPath path
includeText (CppLocalInclude path) = printf "#include \"%s\"" $ unixifyPath path

instance CppFormattable CppIncludes where
    formatCpp (headerIncludes, cppIncludes) =
        let formatIncl incl = intercalate "\n" (includeText <$> Set.toList incl)
        in (formatIncl headerIncludes, formatIncl cppIncludes)


data CppForwardDecl = CppForwardDeclClass String [String] -- | CppForwardDeclStruct String
    deriving (Show, Ord, Eq)

data CppGlobalVariable = CppGlobalVariable { _gvName :: String,
                                             _gvType :: String
                                           }
                                           deriving (Show)

type CppIncludes = (Set CppInclude, Set CppInclude)

type CppForwardDecls = Set CppForwardDecl

data CppParts = CppParts { includes     :: CppIncludes
                         , forwardDecls :: CppForwardDecls
                         , typedefs     :: [CppTypedef]
                         , classes      :: [CppClass]
                         , functions    :: [CppFunction]
                         , globalVars   :: [CppGlobalVariable]
                         }
                deriving (Show)
makeLenses ''CppParts



joinParts :: [CppParts] -> CppParts
joinParts parts =
    let collapseIncludes which = which <$> includes <$> parts
    in CppParts (Set.unions $ collapseIncludes fst, Set.unions $ collapseIncludes snd) 
                (Set.unions $ fmap forwardDecls parts) 
                (concat $ map typedefs parts) 
                (concat $ map classes parts) 
                (concat $ map functions parts) 
                (concat $ map globalVars parts)


--instance Monoid CppParts where
--    mempty = def
--    mappend lhs rhs =
--        let collapseIncludes which = which <$> includes <$> parts
--        in CppParts (concat $ collapseIncludes fst, concat $ collapseIncludes snd) (Set.unions $ fmap forwardDecls parts) (concat $ map typedefs parts) (concat $ map classes parts) (concat $ map functions parts)

data FormattedCppMethod = FormattedCppMethod
    { _inClassCode :: String
    , _afterClassCode :: String
    , _cppCode :: String
    }
makeLenses ''FormattedCppMethod


instance CppFormattable CppFunction where
    formatCpp (CppFunction n r a b) = 
        let at = formatArgsList a :: String
            signature = printf "%s %s%s" r n at
            body = printf "{\n%s\n}" b
        in (signature <> ";", signature <> "\n" <> body)

formatMethod :: CppMethod -> CppClass -> FormattedCppMethod
formatMethod mth@(CppMethod (CppFunction n r a b) q s) cls@(CppClass cn _ _ _ tmpl _) =
    let st = format s :: String
        rt = r :: String
        nt = n :: String
        at = formatArgsList a :: String
        qt = format q :: String
        signatureHeader = printf "\t%s%s %s%s%s;" st rt nt at qt :: String

        scope = templateDepName cls
        templateIntr = formatTemplateIntroductor tmpl
        qst = format $ filter ((==) ConstQualifier) q -- qualifiers signature text
        signatureImpl = printf "%s%s %s::%s%s %s" templateIntr rt scope nt at qst :: String
        implementation = case isPureVirtual mth of
                True -> ""
                _    -> signatureImpl <> "\n{\n" <> b <> "\n}"

    in if null tmpl
       then FormattedCppMethod signatureHeader "" implementation
       else FormattedCppMethod signatureHeader implementation ""


instance HsTyped CppFieldSource where
    hsType (CppFieldSourceRec vst@(n, s, t)) = t
    hsType (CppFieldSourceNormal st@(s, t)) = t

instance HsTyped CppField where
    hsType (CppField{source}) = hsType source

instance CppFormattablePart CppField where
    format field = fieldType field <> " " <> fieldName field

instance CppFormattablePart [CppField] where
    format fields =
        let formatField field = printf "\t%s;" (format field) -- FIXME think think think
            formattedFields = formatField <$> fields
            ret = intercalate "\n" formattedFields
        in ret

instance CppFormattablePart CppAccess where
    format Protected = "protected"
    format Public    = "public"
    format Private   = "private"


--instance CppFormattablePart CppDerive where
--    format (CppDerive base virtual access) = format access <> " " <> (if virtual then "virtual " else "") <> base

--instance CppFormattablePart [CppDerive] where
--    format [] = ""
--    format derives = ": " <> Data.List.intercalate ", " (map format derives)


formatParametrizedName :: String -> [String] -> String
formatParametrizedName name params =
    if null params then
        name
    else
        printf "%s<%s>" name (formatTemplateArgs params)

cppClassTypeUse :: CppClass -> String
cppClassTypeUse cls@(CppClass name _ _ _ tmpl _) = formatParametrizedName name tmpl

class CollapsibleCode a where
    collapseCode :: [a] -> a

instance CollapsibleCode CppFormattedCode where
    collapseCode input =
        ( intercalate "\n" (map fst input)
        , intercalate "\n\n" (map snd input)
        )

instance  CollapsibleCode FormattedCppMethod where
    collapseCode methods = FormattedCppMethod
            (intercalate "\n"    $  _inClassCode <$> methods)
            (intercalate "\n\n"  $  _afterClassCode <$> methods)
            (intercalate "\n\n"  $  _cppCode <$> methods)

hasDtorDefined :: CppClass -> Bool
hasDtorDefined (CppClass clsname _ methods _ _ _) = any isDtor methods where
    isDtor method = (name (function method)) == "~"<>clsname


instance CppFormattable CppClass where
    formatCpp cls@(CppClass name fields methods bases tmpl enums) =
        let formatBase (CppDerive bname bvirt bacc) =
                let baseTempl = if null tmpl then "" else printf "<%s>" (intercalate ", " tmpl)
                in format bacc <> " " <> (if bvirt then "virtual " else "") <> bname <> baseTempl

            basesTxt = if null bases
                then ""
                else ": " <> intercalate ", " (formatBase <$> bases)
            fieldsTxt = format fields
            enumsTxt = if null enums then "" else "\t" <> format enums <> "\n"
            -- fff =  (formatCppCtx <$> methods <*> [cls]) :: [CppFormattedCode]
            (FormattedCppMethod methodsHeader implsHeader methodsImpl) = collapseCode (formatMethod <$> methods <*> [cls])
            templatePreamble = formatTemplateIntroductor tmpl
            dtorCode = if hasDtorDefined cls then "" else printf "\tvirtual ~%s() {}\n" name
            headerCode =
                printf 
                    "%sclass %s %s \n{\npublic:\n%s%s%s\n\n%s\n};\n%s"
                    templatePreamble name basesTxt dtorCode enumsTxt fieldsTxt methodsHeader implsHeader
            bodyCode = methodsImpl
        in (headerCode, bodyCode)

instance CppFormattable CppForwardDecl where
    formatCpp (CppForwardDeclClass name tmpl) = (printf "%sclass %s;" (formatTemplateIntroductor tmpl) name, "")
    -- formatCpp (CppForwardDeclStruct name) = (printf "struct %s;" name, "")

instance CppFormattable CppTypedef where
    formatCpp (CppTypedef to from tmpl) =
        let templateList = formatTemplateIntroductor tmpl
        in (printf "%susing %s = %s;" templateList to from, "")

instance  CppFormattable CppGlobalVariable where
    formatCpp (CppGlobalVariable n t) = (printf "extern %s %s;" t n, printf "%s %s;" t n) 

instance CppFormattable CppParts where
    formatCpp (CppParts incl frwrds tpdefs cs fns vars) =
        let includesPieces = formatCpp incl
            forwardDeclPieces = map formatCpp (Set.toList frwrds)
            typedefPieces = map formatCpp tpdefs
            classesCodePieces = map formatCpp cs
            functionsPieces = map formatCpp fns
            globalVarsPieces = map formatCpp vars
            -- FIXME code duplication above

            allPieces = concat [[includesPieces], forwardDeclPieces, typedefPieces, classesCodePieces, functionsPieces, globalVarsPieces]
            -- replicate 10 '*'
            collectCodePieces fn = Data.List.intercalate "\n\n/****************/\n\n" (map fn allPieces)
            headerCode = collectCodePieces fst
            bodyCode = collectCodePieces snd
        in (headerCode, bodyCode)

formatTemplateArgs :: [String] -> String
formatTemplateArgs tmpl = intercalate ", " (map ((<>) "typename ") tmpl)

formatTemplateIntroductor :: [String] -> String
formatTemplateIntroductor tmpl = if null tmpl then "" else
                                    printf "template<%s>\n" (formatTemplateArgs tmpl) :: String

standardSystemIncludes :: Set CppInclude
standardSystemIncludes = Set.fromList $ map CppSystemInclude ["memory", "vector", "string"]

translateToCppNameQualified :: Name -> String
translateToCppNameQualified name =
    let repl '.' = '_'
        repl c = c
    in map repl $ show name

translateToCppNamePlain :: Name -> String
translateToCppNamePlain = nameBase

class PureVirtualMethodInfo a where
    pureVirtualMethod :: a -> CppMethod

instance PureVirtualMethodInfo (String, String, [CppArg], String) where
    pureVirtualMethod (name, ret, args, body) =
        pureVirtualMethod $ CppFunction name ret args body

instance PureVirtualMethodInfo CppFunction where
    pureVirtualMethod fn = CppMethod fn [PureVirtualQualifier] Virtual

whichFunction :: String -> [String] -> String -> CppFunction
whichFunction baseName baseParams body =
    CppFunction "which" (templateDepTypenameBase baseName baseParams <> "::Constructors") [] body

generateRootClassWrapper :: Dec -> [CppClass] -> CppClass
generateRootClassWrapper (DataD cxt name tyVars cons names) derClasses =
    let tnames = tyvarToCppName <$> tyVars
        n = translateToCppNameQualified name
        initialCls = CppClass n [] [] [] tnames []
        deserializeMethod = prepareDeserializeMethodBase initialCls derClasses
        serializeMethod = pureVirtualMethod ("serialize", "void",
            [CppArg "output" "Output &"],
            "assert(0); // pure virtual function")
        whichConMethod = pureVirtualMethod $ whichFunction n tnames "assert(0); // pure virtual function"
        consEnum = CppEnum "Constructors" (translateToCppNamePlain <$> hsName <$> cons)
    in CppClass n [] [serializeMethod, deserializeMethod, whichConMethod] [] tnames [consEnum]

class IsValueType a where
    isValueType :: a -> Q Bool

instance IsValueType Info where
    isValueType (TyConI (TySynD name vars t)) = isValueType t
    isValueType _ = return False

instance IsValueType Type where
    isValueType (VarT name) = return True :: Q Bool
    isValueType ListT = return True
    isValueType (TupleT _) = return True
    isValueType (AppT base nested) = isValueType base
    isValueType (ConT name) | (elem name builtInTypes) = return True
                            -- | otherwise = do
    isValueType (ConT name) = do
        info <- reify name
        isValueType info
    isValueType _ = return False

templateDepNameBase :: String -> [String] -> String
templateDepNameBase clsName tmpl = if null tmpl then clsName else printf "%s<%s>" clsName $ intercalate "," tmpl

templateDepTypenameBase :: String -> [String] -> String
templateDepTypenameBase clsName tmpl = if null tmpl then clsName else printf "typename %s<%s>" clsName $ intercalate "," tmpl

templateDepName :: CppClass -> String
templateDepName cls@(CppClass clsName _ _ _ tmpl _) = templateDepNameBase clsName tmpl

data TypeDeducingMode = TypeField | TypeAlias
    deriving (Show)

browseAppTree :: Type -> (Type, [Type]) -- returns (Base, [params])
browseAppTree (AppT l r) =
    let (base, paramsTail) = browseAppTree l
    in (base, paramsTail <> [r])
browseAppTree t = (t, [])

-------------------------------------------------------------------------------
builtInTypes = [''Maybe, ''String, ''Int, ''Int32, ''Int64, ''Int16, ''Int8, ''Float, ''Double, ''Char]



hsTypeToCppType :: Type -> TypeDeducingMode -> Q String
hsTypeToCppType t@(ConT name) tdm = do
    let nb = translateToCppNameQualified name
    byValue <- isValueType t
    -- trace ("Koza " ++ show t ++ " value? " ++ show byValue ++ "#" ++ show tdm) (return ())
    return $
        if name == ''String then "std::string"
        else if name == ''Int then "std::int64_t" --"int"
        else if name == ''Int64 then "std::int64_t"
        else if name == ''Int32 then "std::int32_t"
        else if name == ''Int16 then "std::int16_t"
        else if name == ''Int8 then "std::int8_t"
        else if name == ''Float then "float"
        else if name == ''Double then "double"
        else if name == ''Char then "char"
        else if byValue then nb
        else case tdm of
            TypeField -> "std::shared_ptr<" <> nb <> ">"
            TypeAlias -> nb

hsTypeToCppType t@(AppT (ConT base) nested) tdm | (base == ''Maybe) = do
    nestedName <- hsTypeToCppType nested tdm
    shouldCollapse <- isCollapsedMaybePtr t
    return $ if shouldCollapse
             then nestedName
             else "boost::optional<" <> nestedName <> ">"

hsTypeToCppType (AppT ListT (nested)) tdm = do
    nestedType <- hsTypeToCppType nested tdm
    return $ printf "std::vector<%s>" $ nestedType
--typeOfField (AppT ConT (maybe)) = printf "boost::optional<%s>" $ typeOfField nested

hsTypeToCppType (VarT n) tdm = return $ show n

hsTypeToCppType t@(AppT _ _) tdm = do
    -- trace ("Gęś " ++ show t) (return ())
    let (baseType, paramTypes) = browseAppTree t
    baseTypename <- hsTypeToCppType baseType TypeAlias
    argTypenames <- sequence (hsTypeToCppType <$> paramTypes <*> [TypeField])
    isBaseVal <- isValueType baseType
    let paramTypesList = intercalate ", " argTypenames
    return $ printf (if isBaseVal then "%s<%s>" else "std::shared_ptr<%s<%s>>") baseTypename paramTypesList

hsTypeToCppType t@(TupleT 0) tdm = return "std::tuple<>"
hsTypeToCppType t@(TupleT _) tdm = return "std::tuple"

hsTypeToCppType t tdm = return $ trace ("FIXME: hsTypeToCppType for " <> show t) $ "[" <> show t <> "]"

-------------------------------------------------------------------------------


nonValueAliasDependencies :: Type -> Q [Name]
nonValueAliasDependencies con@(ConT name) = do
    info <- reify name
    --trace ("\t:::::" <>show info) $ return ()
    case info of
        TyConI (DataD _ _ _ _ _) -> do
            isValue <- isValueType con
            return $ if name `elem` builtInTypes || isValue then [] else [name]
        TyConI (TySynD _ _ rhsType) -> nonValueAliasDependencies rhsType
        _ -> return []

nonValueAliasDependencies app@(AppT base rhs) = do
    -- trace ("\t|||||" <>show app) $ return ()
    a <- nonValueAliasDependencies base
    b <- nonValueAliasDependencies rhs
    return $ a <> b
nonValueAliasDependencies arg = return [] -- trace ("\t+++++" <> show arg) return []

dependenciesFromAliasUsage :: Type -> Q [Name]
dependenciesFromAliasUsage con@(ConT name) = do
    info <- reify name
    case info of
        TyConI (TySynD _ _ rhsType) -> nonValueAliasDependencies con
        _ -> return []
dependenciesFromAliasUsage _ = return []


-------------------------------------------------------------------------------


typeOfField t = hsTypeToCppType t TypeField

typeOfAlias :: Type -> Q String
typeOfAlias t = hsTypeToCppType t TypeAlias

isCollapsedMaybePtr :: Type -> Q Bool
isCollapsedMaybePtr (AppT (ConT base) nested) | (base == ''Maybe) = do
    nestedName <- typeOfField nested
    isNestedValue <- isValueType nested
    return $ not isNestedValue
isCollapsedMaybePtr _ = return False


class HasCppWrapper a where
    whatComesFrom :: a -> Q CppWrapperType

instance HasCppWrapper Info where
    whatComesFrom info = do
        return $ case info of
            TyConI dec -> case dec of
                DataD cxt name params cons names
                    -> CppWrapperTypeClass dec
                TySynD name params dstType
                    -> CppWrapperAlias dec
                _
                    -> error $ "whatComesFrom fails for " ++ show info
            _ -> error $ "whatComesFrom fails for " ++ show info

instance HasCppWrapper Name where
    whatComesFrom name = reify name >>= whatComesFrom

instance Default CppParts where
    def = CppParts def def []  [] [] []

emptyQParts :: Q CppParts
emptyQParts = return def

processField :: THS.VarStrictType -> Q CppField
processField field@(name, _, t) = do
    filedType <- typeOfField t
    return $ CppField (translateToCppNamePlain name) filedType (CppFieldSourceRec field)

processField2 :: THS.StrictType -> Int -> Q CppField
processField2 field@(_, t) index = do
    filedType <- typeOfField t
    return $ CppField ("field_" <> show index) filedType (CppFieldSourceNormal field)

deserializeFromFName = "deserializeFrom"


prepareDeserializeMethodBase :: CppClass -> [CppClass] -> CppMethod
prepareDeserializeMethodBase cls@(CppClass clsName _ _ _ tmpl _) derClasses =
    let fname = deserializeFromFName
        arg = CppArg "input" "Input &"
        rettype = printf "std::shared_ptr<%s>" $ if null tmpl then clsName
            else templateDepName cls

        returnDeserialize conName = printf "return %s::deserializeFrom(input);" (templateDepNameBase conName tmpl) :: String

        indices = [0 ..  (length derClasses)-1]
        caseForCon index =
            let ithCon =  derClasses !! index
                conName = ithCon ^. className
            in printf "case %d: %s" index (returnDeserialize conName) :: String

        cases = map caseForCon indices

        -- If there is only one constructor, we omit its index.
        body = if length derClasses == 1 then
                let conName = (derClasses !! 0) ^. className
                in [returnDeserialize conName]
               else
                [ "auto constructorIndex = readInt8(input);"
                , "switch(constructorIndex)"
                , "{"
                ] <> cases <>
                [ "default: return nullptr;"
                , "}"
                ]

        prettyBody = intercalate "\n" (map ((<>) "\t") body)

        fun = CppFunction fname rettype [arg] prettyBody
    in CppMethod fun [] Static

inputArg = CppArg "input" "Input &"

deserializeField :: CppField -> Q String
deserializeField field@(CppField fieldName fieldType fieldSrc) = do
    collapsedMaybe <- isCollapsedMaybePtr (hsType fieldSrc)
    let fname = if collapsedMaybe then "deserializeMaybe" else "deserialize"
    return $ printf "\t::%s(this->%s, input);" fname fieldName

deserializeReturnSharedType :: CppClass -> String
deserializeReturnSharedType cls@(CppClass clsName _ _ _ tmpl _) =
    if null tmpl then clsName else templateDepName cls

deserializeReturnType :: CppClass -> String
deserializeReturnType cls = printf "std::shared_ptr<%s>" $ deserializeReturnSharedType cls

prepareDeserializeMethodDer :: CppClass -> Q CppMethod
prepareDeserializeMethodDer cls@(CppClass clsName _ _ _ tmpl _)  = do
    fieldsCode <- sequence (map deserializeField $ cls^.classFields)
    let body = intercalate "\n" $ fieldsCode
        fun = CppFunction "deserialize" "void" [inputArg] body
    return $ CppMethod fun [] Usual

prepareDeserializeFromMethodDer :: CppClass -> Q CppMethod
prepareDeserializeFromMethodDer cls@(CppClass clsName _ _ _ tmpl _)  = do
    let fname = deserializeFromFName
        clsName = cls ^. className
        --deserializeField field@(CppField fieldName fieldType fieldSrc) = printf "\tdeserialize(ret->%s, input);" fieldName :: String

    let bodyOpener = printf "\tauto ret = std::make_shared<%s>();" (deserializeReturnSharedType cls) :: String
        bodyMiddle = "\tret->deserialize(input);"
        bodyCloser = "\treturn ret;"
        body = intercalate "\n" $ [bodyOpener, bodyMiddle, bodyCloser]

        fun = CppFunction fname (deserializeReturnType cls) [inputArg] body
        qual = []
        stor = Static
    return $ CppMethod fun qual stor


serializeField :: CppField -> Q String
serializeField field@(CppField fieldName fieldType fieldSrc) = do
    collapsedMaybe <- isCollapsedMaybePtr (hsType fieldSrc)
    let fname = if collapsedMaybe then "serializeMaybe" else "serialize"
    return $ printf "\t::%s(this->%s, output);" fname fieldName

initializingCtor :: String -> [CppField] -> CppMethod
initializingCtor n fields = CppMethod (CppFunction n "" args body) [] Usual where
    arg field = CppArg (fieldName field) (fieldType field)
    assignment field = let fn = (fieldName field) in printf "\tthis->%s = %s;" fn fn
    body = (intercalate "\n" $ assignment <$> fields)
    args = arg <$> fields

processConstructor :: Dec -> Con -> Q CppClass
processConstructor dec@(DataD cxt name tyVars cons names) con =
    do
        let baseCppName = translateToCppNameQualified name
            tnames = map tyvarToCppName tyVars

        let cname = hsName con
        let prettyConName = translateToCppNamePlain cname

        cppFields <- case con of
                RecC _ fields      -> mapM processField fields
                NormalC _ fields   ->
                    let fields' = processField2 <$> fields :: [Int -> Q CppField]
                        r = zipWith ($) fields' [0 ..]
                    in sequence r
                _             -> return []

        let derCppName = baseCppName <> "_" <> prettyConName
        let baseClasses   = [CppDerive baseCppName False Public]
            classInitial  = CppClass derCppName cppFields [] baseClasses tnames []
            Just index    = elemIndex con cons
        serializeFieldsLines <- sequence $ (serializeField <$> cppFields)

        -- Omit constructor index if there is only one constructor
        let serializeConIndex = if length cons == 1 then [] else [printf "\t::serialize(std::int8_t(%d), output);" index] :: [String]
        let serializeCode = intercalate "\n" (serializeConIndex <> serializeFieldsLines)
            serializeFn   = CppFunction "serialize" "void" [CppArg "output" "Output &"] serializeCode
            --serializeField field = printf "\t::serialize(%s, output);" (fieldName field) :: String

        let serializeMethod = CppMethod serializeFn [OverrideQualifier] Virtual
        deserializeFromMethod <- prepareDeserializeFromMethodDer classInitial
        deserializeMethod <- prepareDeserializeMethodDer classInitial

        let defaultCtor = CppMethod (CppFunction derCppName "" [] "") [] Usual
        let initCtor = initializingCtor derCppName cppFields

        let whichMethod =
                let whichFn = whichFunction baseCppName tnames ("\treturn " <> (templateDepTypenameBase baseCppName tnames) <> "::" <> prettyConName <> ";")
                in CppMethod whichFn [OverrideQualifier] Virtual

        let methods = [defaultCtor, initCtor, serializeMethod, deserializeMethod, deserializeFromMethod, whichMethod]
        return $ CppClass derCppName cppFields methods baseClasses tnames []
processConstructor dec arg = trace ("FIXME: Con for " <> show arg) (return $ CppClass "" [] [] [] [] [])

tyvarToCppName :: TyVarBndr -> String
tyvarToCppName (PlainTV n) = show n
tyvarToCppName arg = trace ("FIXME: tyvarToCppName for " <> show arg) $ show arg

class ForwardDeclarable a where
    makeForwardDeclaration :: a -> Q CppForwardDecl

instance ForwardDeclarable (Name, [TyVarBndr]) where
    makeForwardDeclaration (name, params) = do
        return $ CppForwardDeclClass (translateToCppNameQualified name) (tyvarToCppName <$> params)

instance ForwardDeclarable Dec where
    makeForwardDeclaration dec = do
        let nameAndParams = case dec of
                (DataD cxt name params cons names) -> (name, params)
                (TySynD name params rhsType)       -> error ("No forward declarations for aliases! " ++ show dec) --(name, params)
                _ -> error ("makeForwardDeclaration Dec " ++ show dec)
        makeForwardDeclaration nameAndParams

instance ForwardDeclarable Name where
    makeForwardDeclaration name = do
        info <- reify name
        case info of
            TyConI dec -> makeForwardDeclaration dec
            _ -> error ("makeForwardDeclaration Name " ++ show name)

instance ForwardDeclarable CppClass where
    makeForwardDeclaration cls = return $ CppForwardDeclClass (cls ^. className) (cls ^. classTemplateParams)

--toForwardDecl :: Name -> Q CppForwardDecl
--toForwardDecl name = do
--    info <- reify name
--    return $ case info of
--        _ -> CppForwardDeclClass (translateToCppNamePlain name) []


makesAlias :: Name -> Q Bool
makesAlias name = do
    info <- reify name
    return $ case info of
        TyConI dec -> isTySynD dec
        _ -> False

generateTypedefCppWrapper :: Dec -> Q CppTypedef
generateTypedefCppWrapper tysyn@(TySynD name tyVars rhstype) = do
    baseTName <- typeOfAlias rhstype
    let tnames = map tyvarToCppName tyVars
    return $ CppTypedef (translateToCppNameQualified name) baseTName tnames
generateTypedefCppWrapper arg = error ("FIXME: generateTypedefCppWrapper for " <> show arg)

includeFor :: Name -> CppInclude
includeFor name = CppLocalInclude (nameToDir name </> nameBase name <> ".h")

class HasThinkableCppDependencies a where
    cppDependenciesParts :: a -> Q CppParts

class ListAliasDependencies a where
    listAliasDependencies :: a -> Q [Name]

instance ListAliasDependencies Info where
    listAliasDependencies (TyConI info) = listAliasDependencies info

instance ListAliasDependencies Type where
    listAliasDependencies (AppT l r) = do
        ldeps <- listAliasDependencies l
        rdeps <- listAliasDependencies r
        return $ ldeps <> rdeps

    listAliasDependencies (ConT n) | (not $ n `elem` builtInTypes) = do
        info <- reify n
        case info of
            TyConI (TySynD _ _ rhs) -> listAliasDependencies rhs
            TyConI (DataD _ _ _ _ _) -> return  [n]
            _ -> return []

    listAliasDependencies _ = return []



instance ListAliasDependencies Dec where
    listAliasDependencies (TySynD name params rhstype) = do
        listAliasDependencies rhstype
    listAliasDependencies _             = return []

instance ListAliasDependencies Name where
    listAliasDependencies n = reify n >>= listAliasDependencies

instance HasThinkableCppDependencies Name where
    cppDependenciesParts name = cppDependenciesParts [name]

instance HasThinkableCppDependencies [Name] where
    cppDependenciesParts dependencies =  do
        reifiedDeps <- sequence $ reify <$> dependencies

        let aliasDepsNames = [n | (TyConI (TySynD n _ _)) <- reifiedDeps]
        let includesForAliases = Set.fromList $ includeFor <$> aliasDepsNames

        let dataDepsDecs = [dec | (TyConI dec) <- reifiedDeps, isDataD dec]
        forwardDecsDeps <- sequence $ makeForwardDeclaration <$> dataDepsDecs
        let includesForDeps = Set.fromList [includeFor n | (DataD _ n _ _ _) <- dataDepsDecs]

        --let functionTypes = [t | var@(VarI _ t _ _) <- reifiedDeps]
        --let functionDeps ftype = argumentTypes ftype <> [returnedType ftype]
        --let signatureTypes = concat $ functionDeps <$> functionTypes :: [Type]

        let includes = (includesForAliases, includesForDeps)
        let frwrdDecs = (Set.fromList forwardDecsDeps)
        let ret = CppParts includes frwrdDecs def def def def
        -- traceM (printf "\t### %s -> \n\t\t%s\n\n" (show dependencies) (show ret))
        return ret

instance HasThinkableCppDependencies (Set Name) where
    cppDependenciesParts dependencies = cppDependenciesParts $ Set.toList dependencies

instance HasThinkableCppDependencies Dec where
    cppDependenciesParts dec = do
        let dependencies = symbolDependencies dec
        cppDependenciesParts dependencies

includesResultingFromAliases :: CppClass -> Q [CppInclude]
includesResultingFromAliases cls = do
    names <- concat <$> (sequence $ listAliasDependencies <$> hsType <$> (cls ^. classFields))  :: Q [Name]
    return $ includeFor <$> names

elevateCommonFields :: CppClass -> [CppClass] -> (CppClass, [CppClass])
elevateCommonFields base [] = (base, [])
elevateCommonFields base ders = 
    let presentIn field cls = elem field (cls ^. classFields)
        presentInAll field = all (presentIn field) ders
        candidates = (head ders) ^. classFields
        toElevate = filter presentInAll candidates

        removeFields cls = cls & classFields %~ filter (\x -> not $ elem x toElevate)

        elevatedBase = base & classFields %~ mappend toElevate
        elevDers = removeFields <$> ders        

    in (elevatedBase, elevDers)

generateCppWrapperHlp :: Dec -> Q CppParts
-- generateCppWrapperHlp arg | trace ("generateCppWrapperHlp: " <> show arg) False = undefined
generateCppWrapperHlp dec@(DataD cxt name tyVars cons names) =
    do
        derClasses <- sequence $ processConstructor <$> [dec] <*> cons
        let baseClass = generateRootClassWrapper dec derClasses
        depParts <- cppDependenciesParts dec

        forwardDecsClasses <- sequence $ [makeForwardDeclaration baseClass]

        additionalIncludes <- sequence $ includesResultingFromAliases <$> derClasses
         -- traceM $ printf "$$$ %s -> %s" (show dec) (show additionalIncludes)
        let includes    = (standardSystemIncludes, Set.fromList $ concat additionalIncludes)
        let forwardDecs = Set.fromList forwardDecsClasses
        let aliases     = []
        --let classes     = baseClass : derClasses
        let (elevBase, elevDers) = elevateCommonFields baseClass derClasses
        let elevClasses = elevBase : elevDers
        let functions   = []
        let vars        = []



        let mainParts = CppParts includes forwardDecs aliases elevClasses functions vars

        return $ joinParts [depParts, mainParts]

generateCppWrapperHlp tysyn@(TySynD name tyVars rhstype) = do
    -- trace ("\tGenerating wrapper for " <> show tysyn) $ return ()
    tf <- generateTypedefCppWrapper tysyn
    depParts <- cppDependenciesParts tysyn
    return $ joinParts [depParts, (CppParts def def [tf] [] [] [])]

generateCppWrapperHlp arg = trace ("FIXME: generateCppWrapperHlp for " <> show arg) emptyQParts

instance TypesDependencies Type where
    --symbolDependencies t | trace ("Type: " <> show t) False = undefined

    -- Maybe and String are handled as a special-case
    symbolDependencies (ConT name) | (elem name builtInTypes) = Set.empty

    symbolDependencies ArrowT                           = Set.empty
    symbolDependencies contype@(ConT name)              = Set.singleton name
    symbolDependencies apptype@(AppT ListT nested)      = symbolDependencies nested
    symbolDependencies apptype@(AppT (TupleT _) nested) = symbolDependencies nested
    symbolDependencies apptype@(AppT base nested)       = symbolDependencies
                                                                    [base, nested]
    symbolDependencies vartype@(VarT n)                 = Set.empty
    symbolDependencies (TupleT 0)                       = Set.empty

    symbolDependencies t = trace ("FIXME not handled type: " <> show t) Set.empty


instance (TypesDependencies a, Show a) => TypesDependencies [a] where
    --symbolDependencies t | trace ("list: " <> show t) False = undefined
    symbolDependencies listToProcess =
        let listOfSets = (map symbolDependencies listToProcess)::[Set Name]
        in Set.unions listOfSets

instance TypesDependencies (THS.Strict, Type) where
    symbolDependencies (_, t) = symbolDependencies t

instance TypesDependencies Con where
    --symbolDependencies t | trace ("Con: " <> show t) False = undefined
    symbolDependencies (RecC name fields) = symbolDependencies fields
    symbolDependencies (NormalC name fields) = symbolDependencies fields
    symbolDependencies t = trace ("FIXME not handled Con: " <> show t) (errorWithStackTrace) []

instance TypesDependencies VarStrictType where
    --symbolDependencies t | trace ("Field: " <> show t) False = undefined
    symbolDependencies (_, _, t) = symbolDependencies t

instance TypesDependencies Dec where
    symbolDependencies (DataD _ n _ cons _) = symbolDependencies cons
    symbolDependencies (TySynD n _ t) = symbolDependencies t
    symbolDependencies arg = trace ("FIXME not handled Dec: " <> show arg) (Set.empty)

instance TypesDependencies Info where
--    symbolDependencies t | trace ("Info: " <> show t) False = undefined
    symbolDependencies (TyConI dec) = symbolDependencies dec
    symbolDependencies (VarI n t _ _) = symbolDependencies t
    symbolDependencies arg = trace ("FIXME not handled Info: " <> show arg) (Set.empty)


collectDirectDependencies :: Name -> Q [Name]
-- collectDirectDependencies name | trace ("collectDirectDependencies " <> show name) False = undefined
collectDirectDependencies name = do
    nameInfo <- reify name
    let namesSet = symbolDependencies nameInfo
    return $ Set.elems namesSet
    -- evalStateT (blah name) []

generalBfs :: (Name -> Q [Name]) -> [Name] -> [Name] -> Q [Name]
-- generalBfs q d | trace (show q <> "\n\n" <> show d) False = undefined
generalBfs _ [] discovered = return discovered
generalBfs getNeighbours queue discovered = do
    let vertex = head queue
    neighbours <- getNeighbours vertex
    let neighboursToAdd = filter (flip notElem discovered) neighbours
        newQueue        = tail queue <> neighboursToAdd
        newDiscovered   = discovered <> neighboursToAdd
    generalBfs getNeighbours newQueue newDiscovered

--naiveBfs :: [Name] -> [Name] -> Q [Name]
---- naiveBfs q d | trace (show q <> "\n\n" <> show d) False = undefined
--naiveBfs [] discovered = return discovered
--naiveBfs queue discovered = do
--    let vertex = head queue
--    neighbours <- collectDirectDependencies vertex
--    let neighboursToAdd = filter (flip notElem discovered) neighbours
--        newQueue        = tail queue <> neighboursToAdd
--        newDiscovered   = discovered <> neighboursToAdd
--    naiveBfs newQueue newDiscovered

collectDependencies :: Name -> Q [Name]
collectDependencies name = do
    let queue = [name]
    let discovered = [name]
    generalBfs collectDirectDependencies queue discovered

printAst :: Info -> String
printAst  (TyConI dec@(DataD cxt name tyVars cons names)) =
    let namesShown = (show <$> names) :: [String]
        consCount = Data.List.length cons :: Int
        ret = ("cxt=" <> show cxt <> "\nname=" <> show name <> "\ntyVars=" <> show tyVars <> "\ncons=" <> show cons <> "\nnames=" <> show names) :: String
    in show consCount <> "___" <> ret

generateSingleWrapper :: Name -> Q CppParts
generateSingleWrapper arg | trace ("generateSingleWrapper: " <> show arg) False = undefined
generateSingleWrapper name = do
    nameInfo <- reify name
    case nameInfo of
            (TyConI dec)    -> generateCppWrapperHlp dec
            _               -> trace ("ignoring entry " <> show name) emptyQParts

generateWrappers :: [Name] -> Q [CppParts]
generateWrappers names = do
    let partsWithQ = map generateSingleWrapper names
    parts <- sequence partsWithQ
    return parts

generateUnifiedWrapper :: [Name] -> Q CppParts
generateUnifiedWrapper names = do
    parts <- generateWrappers names
    return $ joinParts parts

generateWrapperWithDeps :: Name -> Q CppParts
generateWrapperWithDeps name = do
    relevantNames <- collectDependencies name
    generateUnifiedWrapper relevantNames

formatCppWrapper :: Name -> Q CppFormattedCode
formatCppWrapper arg | trace ("formatCppWrapper: " <> show arg) False = undefined
formatCppWrapper name = do
    parts <- generateWrapperWithDeps name
    return $ formatCpp parts

nameToDir :: Name -> FilePath
nameToDir name =
    joinPath $ case nameModule name of
            Just a -> splitOn "." a
            _ -> []

writeFilePair :: FilePath -> String -> CppParts -> Q ()
writeFilePair outputDir fileBaseName cppParts = do
    let headerBaseName = fileBaseName <.> ".h"
    let headerName = outputDir </> headerBaseName
    let cppName = outputDir </> fileBaseName <.> ".cpp"

    let (headerBody, body) = formatCpp cppParts

    let headerFileContents = printf "#pragma once\n\n%s" headerBody
    let sourceFileContents = (printf "#include \"helper.h\"\n#include \"%s\"\n\n" headerBaseName) <> body

    let tryioaction action = try action :: IO (Either SomeException ())

    runIO $ createDirectoryIfMissing True outputDir
    let writeOutput fname contents = runIO (tryioaction $ writeFile fname contents)

    writeOutput headerName headerFileContents
    writeOutput cppName sourceFileContents
    return ()

writeFileFor :: Name -> FilePath -> Q ()
writeFileFor name outputDir = do

    --hlp <- listAliasDependencies ''Lit2
    --hlp2 <- (sequence $ reify <$> hlp)
    --hlp3 <- ((fmap not) . isValueType) `filterM` hlp2
    --traceM ("*****" <> show hlp)

    deps <- collectDirectDependencies name
    -- runIO $ putStrLn $ printf "Dependencies of %s ==> %s" (show name) (show deps)

    parts <- generateSingleWrapper name

    let outputSubDir = outputDir </> nameToDir name

    writeFilePair outputSubDir (nameBase name) parts

generateCppList :: [Name] -> FilePath -> Q Exp
generateCppList names outputDir = do
    allNames <- (Set.toList . Set.fromList . concat) <$> (sequence $ collectDependencies <$> names)
    sequence $ generateCpp <$> allNames <*> [outputDir]
    [|  return () |]

generateCpp :: Name -> FilePath -> Q Exp
generateCpp name outputDir = do

    deps <- collectDependencies 'formatSignature
    --let deps = symbolDependencies 'writeFileFor
    runIO $ putStrLn $ ">>>>>>" <> show deps
    --lit4 <- [t|Lit5|]
    --litdep <- nonValueAliasDependencies lit4
    --runIO $ putStrLn $ show lit4
    --runIO $ putStrLn $ "Foooo /// " ++ show litdep

    dependencies <- collectDependencies name
    runIO (putStrLn $ printf "%s has %d dependencies: %s" (show name) (length dependencies) (show dependencies))
    --    (header,body) <- formatCppWrapper name

    sequence $ writeFileFor <$> dependencies <*> [outputDir]


     --cppParts <- generateWrapperWithDeps name

    -- writeFilePair outputDir "generated" cppParts

    [|  return () |]
