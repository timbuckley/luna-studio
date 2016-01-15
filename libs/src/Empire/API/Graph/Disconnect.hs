module Empire.API.Graph.Disconnect where

import Prologue
import Empire.API.Data.Project (ProjectId)
import Empire.API.Data.Library (LibraryId)
import Empire.API.Data.Node    (NodeId)
import Empire.API.Data.Port    (OutPort, InPort)

data Disconnect = Disconnect { _projectId :: ProjectId
                             , _libraryId :: LibraryId
                             -- , _srcNodeId :: NodeId   -- not used
                             -- , _srcPort   :: OutPort  -- not used
                             , _dstNodeId :: NodeId
                             , _dstPort   :: InPort
                             } deriving (Show, Eq)

makeLenses ''Disconnect
