{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

{-# OPTIONS_HADDOCK hide #-}

module Command.Script.Validation
    ( Cmd
    , mod
    , run

    ) where

import Prelude hiding
    ( mod )

import Cardano.Address.Script
    ( KeyHash
    , Script (..)
    , ValidationLevel (..)
    , prettyErrValidateScript
    , validateScript
    )
import Data.Maybe
    ( fromMaybe )
import Options.Applicative
    ( CommandFields
    , Mod
    , command
    , footerDoc
    , header
    , helper
    , info
    , optional
    , progDesc
    )
import Options.Applicative.Help.Pretty
    ( bold, indent, string, vsep )
import Options.Applicative.Script
    ( levelOpt, scriptArg )
import System.IO
    ( stderr, stdout )
import System.IO.Extra
    ( hPutString, progName )

data Cmd = Cmd
    { script :: Script KeyHash
    , validationLevel :: Maybe ValidationLevel
    } deriving (Show)

mod :: (Cmd -> parent) -> Mod CommandFields parent
mod liftCmd = command "validate" $
    info (helper <*> fmap liftCmd parser) $ mempty
        <> progDesc "Validate a script"
        <> header "Choose a required (default) or recommended validation of a script."
        <> footerDoc (Just $ vsep
            [ string "The script is taken as argument. To have required validation pass '--required' or nothing."
            , string "To have recommended validation pass '--recommended'. Recommended validation adds more validations"
            , string "on top of the required one, in particular:"
            , string " - check if 'all' is non-empty"
            , string " - check if there are redundant timelocks in a given level"
            , string " - check if there are no duplicated verification keys in a given level"
            , string " - check if 'at_least' coeffcient is positive"
            , string " - check if 'all', 'any' are non-empty and `'at_least' has no less elements in the list than the coeffcient after timelocks are filtered out. "
            , string "The validation of the script does not take into account transaction validity. We assume that the wallet will take care of this upon sending"
            , string "transaction with a given script."
            , string ""
            , string "Example:"
            , indent 2 $ bold $ string $ progName<>" script validate 'all"
            , indent 4 $ bold $ string "[ script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string ", script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyrenxv223vj"
            , indent 4 $ bold $ string "]'"
            , indent 2 $ string "Validated."
            , string ""
            , indent 2 $ bold $ string $ progName<>" script validate --required 'all"
            , indent 4 $ bold $ string "[ script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string ", script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyrenxv223vj"
            , indent 4 $ bold $ string "]'"
            , indent 2 $ string "Validated."
            , string ""
            , indent 2 $ bold $ string $ progName<>" script validate --recommended 'all []'"
            , indent 2 $ string "Not validated: The list inside a script is empty."
            , string ""
            , indent 2 $ bold $ string $ progName<>" script validate 'at_least 1 [active_from 11, active_until 16]'"
            , indent 2 $ string "Validated."
            , string ""
            , indent 2 $ bold $ string $ progName<>" script validate 'all"
            , indent 4 $ bold $ string "[ script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string ", script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string "]'"
            , indent 2 $ string "Validated."
            , string ""
            , indent 2 $ bold $ string $ progName<>" script validate --recommended 'all"
            , indent 4 $ bold $ string "[ script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string ", script_vkh18srsxr3khll7vl3w9mqfu55n6wzxxlxj7qzr2mhnyreluzt36ms"
            , indent 4 $ bold $ string "]'"
            , indent 2 $ string "Not validated: The list inside a script has duplicate keys."
            ])
  where
    parser = Cmd
        <$> scriptArg
        <*> optional levelOpt

run :: Cmd -> IO ()
run Cmd{script,validationLevel} =
    case validateScript (fromMaybe RequiredValidation validationLevel) Nothing script of
        Left err -> hPutString stderr $ "Not validated: " <> prettyErrValidateScript err
        Right _ -> hPutString stdout "Validated."
