{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Strategy.Fandango where

import Etna.Lib hiding (qcfDefaults, qcfRunArb)
import Debug.Trace
import Impl
import QuickCheckWithFandango
import Spec
import Test.QuickCheck
import Etna.Lib.Types (Approach(..))

-- instance Arbitrary BST where
--   arbitrary = do
--     t <- fandangoGen "<tree>"
--     return $ trace (show t) t

-- instance Arbitrary Key where
--   arbitrary = do
--     k <- fandangoGen "<key>"
--     return $ trace (show k) k

-- instance Arbitrary Val where
--   arbitrary = do
--     v <- fandangoGen "<value>"
--     return $ trace (show v) v

instance Arbitrary BST where
  arbitrary = do
    t <- fandangoGenBST
    return $ trace ("Arb: " ++ show t) t

instance Arbitrary Key where
  arbitrary = do
    k <- fandangoGenKey
    return $ trace ("Arb: " ++ show k) k

instance Arbitrary Val where
  arbitrary = do
    v <- fandangoGenVal
    return $ trace ("Arb: " ++ show v) v

$( mkStrategies
     [|qcfRunArb qcfDefaults Naive|]
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