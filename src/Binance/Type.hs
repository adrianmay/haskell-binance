{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}

module Binance.Type
    ( ServerTime(..)
    , AllOrdersRequest(..)
    , AllOrdersResponseLine(..)
    , MyTradesRequest(..)
    , MyTradesResponseLine(..)
    , AccountRequest(..)
    , AccountResponseStupid(..)
    , AccountResponseBalanceStupid(..)
    , saneAccountResponse
    , AccountResponseSane(..)
    , AccountResponseBalanceSane(..)
    , arbTotal
    , BinanceConfig(..)
    , BinanceUserApi(..)
    , TestOrderRequest(..)
    , Deal(..)
    , WT(..)
    , Side(..)
    , OrderType(..)
    -- , Response(..)
    , StreamType(..)
    ) where

import Data.Int
import Data.Time.Format
import Data.Time
import Data.Char
import           Network.WebSockets (WebSocketsData(..), DataMessage(..))
import           Binance.Prelude
import           Data.Aeson (decode)
import qualified Data.Aeson.Types    as A (Options (..))
import qualified Data.Text as T
import           Data.ByteString     (ByteString)
import           Network.HTTP.Client (Manager)
import           Prelude             hiding (String)


------------------------------------------------------------
-- BINANCE DATA
--
data BinanceConfig = BinanceConfig
    { url        :: !BaseUrl
    , managr     :: !Manager
    , publicKey  :: !Text
    , privateKey :: !ByteString
    }

newtype BinanceUserApi a = BinanceUserApi
    { api :: (ReaderT BinanceConfig IO) a
    } deriving ( Applicative
               , Functor
               , Monad
               , MonadIO
               , MonadReader BinanceConfig
               )

newtype ServerTime = ServerTime
    { serverTime :: Integer
    } deriving (Eq, Show, Generic)

instance FromJSON ServerTime

----------------------------------------

data AllOrdersRequest = AllOrdersRequest
    { aopSymbol     :: !Text
    , aopOrderId    :: Maybe Integer
    , aopLimit      :: Maybe Int
    , aopRecvWindow :: Maybe Integer
    , aopTimestamp  :: !Integer
    } deriving (Eq, Show, Generic)

instance ToForm AllOrdersRequest where
    toForm = genericToForm opts
      where
        opts = FormOptions {fieldLabelModifier = uncapitalizeFirst . drop 3 }

data AllOrdersResponseLine = AllOrdersResponseLine
    { aorSymbol        :: !Text
    , aorOrderId       :: !Int
    , aorClientOrderId :: !Text
    , aorPrice         :: !Text
    , aorOrigQty       :: !Text
    , aorExecutedQty   :: !Text
    , aorStatus        :: !Text
    , aorTimeInForce   :: !Text
    , aorType          :: !Text
    , aorSide          :: !Text
    , aorStopPrice     :: !Text
    , aorIcebergQty    :: !Text
    , aorTime          :: !Integer
    , aorIsWorking     :: !Bool
    } deriving (Eq, Show, Generic)

instance FromJSON AllOrdersResponseLine where
    parseJSON = genericParseJSON $ defaultOptions {A.fieldLabelModifier = uncapitalizeFirst . drop 3}

----------------------------------------

data MyTradesRequest = MyTradesRequest
    { mtpSymbol     :: !Text
    , mtpFromId     :: Maybe Integer
    , mtpLimit      :: Maybe Int
    , mtpRecvWindow :: Maybe Integer
    , mtpTimestamp  :: !Integer
    } deriving (Eq, Show, Generic)

instance ToForm MyTradesRequest where
    toForm = genericToForm opts
      where
        opts = FormOptions {fieldLabelModifier = uncapitalizeFirst . drop 3 }

data MyTradesResponseLine = MyTradesResponseLine
    { mtrSymbol           :: !Text
    , mtrId               :: !Int
    , mtrOrderId          :: !Int
    , mtrOrderListId      :: !Int
    , mtrPrice            :: !Text
    , mtrQty              :: !Text
    , mtrQuoteQty         :: !Text
    , mtrCommission       :: !Text
    , mtrCommissionAsset  :: !Text
    , mtrTime             :: !Integer
    , mtrIsBuyer          :: !Bool
    , mtrIsMaker          :: !Bool
    , mtrIsBestMatch      :: !Bool
    } deriving (Eq, Show, Generic)

instance FromJSON MyTradesResponseLine where
    parseJSON = genericParseJSON $ defaultOptions {A.fieldLabelModifier = uncapitalizeFirst . drop 3}

----------------------------------------

data AccountRequest = AccountRequest
    { apRecvWindow :: Maybe Integer
    , apTimestamp  :: !Integer
    } deriving (Eq, Show, Generic)

instance ToForm AccountRequest where
    toForm = genericToForm opts
      where
        opts = FormOptions {fieldLabelModifier = uncapitalizeFirst . drop 2 }

data AccountResponseBalanceStupid = AccountResponseBalanceStupid
  { arbsAsset  :: Text
  , arbsFree   :: Text
  , arbsLocked :: Text
  } deriving (Eq, Show, Generic)

instance FromJSON AccountResponseBalanceStupid where
    parseJSON = genericParseJSON $ defaultOptions {A.fieldLabelModifier = uncapitalizeFirst . drop 4}

data AccountResponseStupid = AccountResponseStupid
  { arsUpdateTime :: Integer
  , arsBalances :: [AccountResponseBalanceStupid]
  } deriving (Eq, Show, Generic)

instance FromJSON AccountResponseStupid where
    parseJSON = genericParseJSON $ defaultOptions {A.fieldLabelModifier = uncapitalizeFirst . drop 3}

data AccountResponseBalanceSane = AccountResponseBalanceSane
  { arbAsset  :: Text
  , arbFree   :: Float
  , arbLocked :: Float
  } deriving (Eq, Show, Generic)

arbTotal :: AccountResponseBalanceSane -> Float
arbTotal AccountResponseBalanceSane{..} = arbFree + arbLocked

data AccountResponseSane = AccountResponseSane
  { arUpdateTime :: Integer
  , arBalances :: [AccountResponseBalanceSane]
  } deriving (Eq, Show, Generic)

saneAccountResponse :: AccountResponseStupid -> AccountResponseSane
saneAccountResponse ars = AccountResponseSane (arsUpdateTime ars) (saneAccountResponseBalance <$> arsBalances ars)

saneAccountResponseBalance :: AccountResponseBalanceStupid -> AccountResponseBalanceSane
saneAccountResponseBalance arbs = AccountResponseBalanceSane
  (arbsAsset arbs)
  (read $ T.unpack $ arbsFree arbs)
  (read $ T.unpack $ arbsLocked arbs)

----------------------------------------

data Side
    = BUY
    | SELL
    deriving (Eq, Show, Read, Generic)

instance FromJSON Side


instance ToHttpApiData Side where
    toUrlPiece = pack . show
    toEncodedUrlPiece = unsafeToEncodedUrlPiece

instance FromHttpApiData Side where
    parseUrlPiece "BUY" = Right BUY
    parseUrlPiece "SELL" = Right SELL
    parseUrlPiece _ = Left "Invalid side (should be BUY or SELL)"


data OrderType
    = LIMIT
    | MARKET
    | STOP_LOSS
    | STOP_LOSS_LIMIT
    | TAKE_PROFIT
    | TAKE_PROFIT_LIMIT
    | LIMIT_MAKER
    deriving (Eq, Show, Generic)

instance FromJSON OrderType

instance ToHttpApiData OrderType where
    toUrlPiece = pack . show
    toEncodedUrlPiece = unsafeToEncodedUrlPiece

instance FromHttpApiData OrderType where
    parseUrlPiece "LIMIT" = Right LIMIT
    parseUrlPiece "MARKET" = Right MARKET
    parseUrlPiece "STOP_LOSS" = Right STOP_LOSS
    parseUrlPiece "STOP_LOSS_LIMIT" = Right STOP_LOSS_LIMIT
    parseUrlPiece "TAKE_PROFIT" = Right TAKE_PROFIT
    parseUrlPiece "TAKE_PROFIT_LIMIT" = Right TAKE_PROFIT
    parseUrlPiece "LIMIT_MAKER" = Right LIMIT_MAKER
    parseUrlPiece _ = Left "Invalid order type"

-- data Response
--     = ACK
--     | RESULT
--     | FULL
--     deriving (Eq, Show, Generic)
-- 
-- instance ToHttpApiData Response where
--     toUrlPiece = pack . show
--     toEncodedUrlPiece = unsafeToEncodedUrlPiece
-- 
-- instance FromHttpApiData Response where
--     parseUrlPiece "ACK" = Right ACK
--     parseUrlPiece "RESULT" = Right RESULT
--     parseUrlPiece "FULL" = Right FULL
--     parseUrlPiece _ =
--         Left
--             "Invalid response type (should be ACK, RESULT or FULL)"
-- 
-- instance FromJSON Response
-- 
data TestOrderRequest = TestOrderRequest
    { topSymbol           :: !Text
    , topSide             :: !Side
    , topType             :: !OrderType
    , topQuantity         :: !(Maybe Double)
--    , topQuoteOrderQty    :: Maybe Double
--    , topTimeInForce      :: Maybe Text
--    , topPrice            :: Maybe Double
--    , topNewClientOrderId :: Maybe Text
--    , topStopPrice        :: Maybe Double
--    , topIcebergQty       :: Maybe Double
--    , topNewOrderRespType :: Maybe Response
--    , topRecvWindow       :: Maybe Integer
    , topTimestamp        :: !Integer
    } deriving (Eq, Show, Generic)

instance ToForm TestOrderRequest where
    toForm = genericToForm opts
      where
        opts = FormOptions {fieldLabelModifier = uncapitalizeFirst . drop 3}

instance FromForm TestOrderRequest


data StreamType
    = AggTrade
    | Trade
    | Ticker
    | Depth
    deriving (Eq, Generic)

instance Show StreamType where
    show AggTrade = "@aggTrade"
    show Trade    = "@trade"
    show Ticker   = "@ticker"
    show Depth    = "@depth"

data Deal = Deal
  { symbol :: Text
  , time :: Integer
  , tradeId :: Int32
  , price :: Float
  } deriving (Eq)

instance FromJSON Deal where
  parseJSON = withObject "T" $ \o ->
    Deal
      <$> o .: "s"
      <*> o .: "T"
      <*> o .: "t"
      <*> (read <$> o .: "p")


instance ToJSON Deal where
  toJSON Deal{..} =
    object [ "s" .= symbol
           , "T" .= time
           , "t" .= tradeId
           , "p" .= price
           ]

instance WebSocketsData (Maybe Deal) where
  fromDataMessage (Text s _) = fromLazyByteString s
  fromDataMessage (Binary s) = fromLazyByteString s
  fromLazyByteString = decode
  toLazyByteString = encode

data WT = WT
  { stream  :: Text
  , payload :: Deal
  } deriving (Eq)

instance FromJSON WT where
  parseJSON = withObject "WT" $ \o ->
    WT
      <$> o .: "stream"
      <*> o .: "data"

instance ToJSON WT where
  toJSON WT{..} =
    object [ "stream" .= stream
           , "data"   .= payload
           ]

instance WebSocketsData (Maybe WT) where
  fromDataMessage (Text s _) = fromLazyByteString s
  fromDataMessage (Binary s) = fromLazyByteString s
  fromLazyByteString = decode
  toLazyByteString = encode

instance Show Deal where
  show (Deal s t _i p) =
    let tm = parseTimeM True defaultTimeLocale "%s" (show $ t `div` 1000) :: Maybe UTCTime
    in unpack s ++ " " ++ show tm ++ " " ++ show p

-- instance Read Deal where
--   readsPrec _ s =
--     let (ss:ts:ps:_) = words s
--      in [(Deal (pack ss) (read ts) (read ps), "")]

instance Show WT where
  show (WT _ t) = show t

uncapitalizeFirst :: String -> String
uncapitalizeFirst [] = []
uncapitalizeFirst (a:as) = toLower a:as

