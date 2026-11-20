{-# LANGUAGE TemplateHaskell #-}

module Strategy.FandangoGuided where

import Etna.Lib hiding (qcfDefaults, qcfRunArb)
import QuickCheckWithFandango
import Spec
import Test.QuickCheck
import Etna.Lib.Types (Approach(..))
import Strategy.Fandango ()

$( mkStrategies
     [|qcfRunArbFandango True qcfDefaults Naive|]
     [ 'prop_InsertValid,
       'prop_DeleteValid,
       'prop_UnionValid,
       'prop_InsertPost,
       'prop_DeletePost,
       'prop_UnionPost,
       'prop_InsertModel,
       'prop_DeleteModel,
       'prop_UnionModel,
       'prop_InsertInsert,
       'prop_InsertDelete,
       'prop_InsertUnion,
       'prop_DeleteInsert,
       'prop_DeleteDelete,
       'prop_DeleteUnion,
       'prop_UnionDeleteInsert,
       'prop_UnionUnionIdem,
       'prop_UnionUnionAssoc
     ]
 )
