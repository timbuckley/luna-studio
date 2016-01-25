module Empire.API.Library.CreateLibrary where

import           Prologue
import           Data.Binary             (Binary)

import           Empire.API.Data.Project (ProjectId)
import           Empire.API.Data.Library (LibraryId, Library)
import qualified Empire.API.Update     as Update

data Request = Request { _projectId   :: ProjectId
                       , _libraryName :: Maybe String
                       , _path        :: String
                       } deriving (Generic, Show, Eq)

data Result = Result { _libraryId :: LibraryId
                     , _library   :: Library
                     } deriving (Generic, Show, Eq)

type Update = Update.Update Request Result

makeLenses ''Request
makeLenses ''Result

instance Binary Request
instance Binary Result