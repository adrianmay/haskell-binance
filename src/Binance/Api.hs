{-# LANGUAGE NoImplicitPrelude #-}

module Binance.Api
    ( module Binance.Type
    , allOrders
    , myTrades
    , BinanceAccountApi
    , binanceStream
    , binanceProxy
    , getServerTime
    , account
    , testOrder
    ) where

import Binance.Prelude
import Binance.Type (StreamType, ServerTime(..), BinanceUserApi,
                     TestOrderRequest(..),
                     AllOrdersRequest(..), AllOrdersResponseLine(..),
                     MyTradesRequest(..), MyTradesResponseLine(..),
                     AccountRequest(..), AccountResponseStupid(..), AccountResponseBalanceStupid(..),
                     publicKey, privateKey, url, managr, BinanceConfig(..), api, Side(..), OrderType(..),
                     )
import Data.ByteString (ByteString)
import Data.ByteString.Lazy (toStrict)
import Data.Char (toLower)
import Data.List (intercalate)
import Prelude hiding (getLine, null, putStrLn, readFile)

subscribeTo :: String -> ClientApp () -> IO ()
subscribeTo s = withSocketsDo .  runSecureClient "stream.binance.com" 9443 s

makeStreamName :: [(String, StreamType)] -> String
makeStreamName ps = base ++
    intercalate "/" (map (\(sym, t) -> map toLower sym ++ show t) ps)
  where
    base =
        if length ps == 1
            then "/ws/"
            else "/stream?streams="

binanceStream :: [(String, StreamType)] -> ClientApp () -> IO ()
binanceStream [] = error "Please provide at least one symbol and stream type pair"
binanceStream ps = subscribeTo $ makeStreamName ps

------------------------------------------------------------
-- BINANCE USER API

type BinanceAccountApiTime =
  "time" :>
  Get '[ JSON] ServerTime

type BinanceAccountApiAllOrders =
  Header "X-MBX-APIKEY" Text :>
  "allOrders" :>
  QueryParam "symbol" Text :>
  QueryParam "orderId" Integer :>
  QueryParam "limit" Int :>
  QueryParam "recvWindow" Integer :>
  QueryParam "timestamp" Integer :>
  QueryParam "signature" Text :>
  Get '[ JSON] [AllOrdersResponseLine] -- it's a GET so you can't use the body

type BinanceAccountApiMyTrades =
  Header "X-MBX-APIKEY" Text :>
  "myTrades" :>
  QueryParam "symbol" Text :>
  QueryParam "fromId" Integer :>
  QueryParam "limit" Int :>
  QueryParam "recvWindow" Integer :>
  QueryParam "timestamp" Integer :>
  QueryParam "signature" Text :>
  Get '[ JSON] [MyTradesResponseLine]

type BinanceAccountApiAccount =
  Header "X-MBX-APIKEY" Text :>
  "account" :>
  QueryParam "recvWindow" Integer :>
  QueryParam "timestamp" Integer :>
  QueryParam "signature" Text :>
  Get '[ JSON] AccountResponseStupid

type BinanceAccountApiTestOrder =
  Header "X-MBX-APIKEY" Text :>
  "order" :>
  "test" :>
  ReqBody '[FormUrlEncoded] TestOrderRequest :>
  QueryParam "signature" Text :>
  Post '[ JSON] Object

type BinanceAccountApi
     = "api" :> "v3" :>
        (    BinanceAccountApiTime
        :<|> BinanceAccountApiAllOrders
        :<|> BinanceAccountApiMyTrades
        :<|> BinanceAccountApiAccount
        :<|> BinanceAccountApiTestOrder
        )

binanceProxy :: Proxy BinanceAccountApi
binanceProxy = Proxy

getServerTime' :: ClientM ServerTime
allOrders' ::
       Maybe Text
    -> Maybe Text
    -> Maybe Integer
    -> Maybe Int
    -> Maybe Integer
    -> Maybe Integer
    -> Maybe Text
    -> ClientM [AllOrdersResponseLine]
myTrades' ::
       Maybe Text
    -> Maybe Text
    -> Maybe Integer
    -> Maybe Int
    -> Maybe Integer
    -> Maybe Integer
    -> Maybe Text
    -> ClientM [MyTradesResponseLine]
account' ::
       Maybe Text    -- api key
    -> Maybe Integer -- recvWindow
    -> Maybe Integer -- timestamp
    -> Maybe Text    -- sig
    -> ClientM AccountResponseStupid
testOrder' ::
       Maybe Text
    -> TestOrderRequest
    -> Maybe Text
    -> ClientM Object
getServerTime' :<|> allOrders' :<|> myTrades' :<|> account' :<|> testOrder' = client binanceProxy

getServerTime :: BinanceUserApi Integer
getServerTime = do
    url <- asks url
    man <- asks managr
    liftIO $ do
        Right (ServerTime time) <-
            runClientM getServerTime' $
            ClientEnv man url Nothing -- defaultMakeClientRequest
        return time

sign :: ByteString -> BinanceUserApi (Digest SHA256)
sign msg =
    asks privateKey >>= \secret ->
        return . hmacGetDigest . hmac secret $ msg

allOrders ::
       AllOrdersRequest
    -> BinanceUserApi (Either ClientError [AllOrdersResponseLine])
allOrders params@AllOrdersRequest {..} = do
    url <- asks url
    man <- asks managr
    pub <- asks publicKey
    let msg = urlEncodeAsForm params
    sig <- sign $ toStrict msg
    liftIO $
        runClientM
            (allOrders'
                 (Just pub)
                 (Just aopSymbol)
                 aopOrderId
                 aopLimit
                 aopRecvWindow
                 (Just aopTimestamp)
                 (Just ((pack . show) sig))) $
        ClientEnv man url Nothing -- defaultMakeClientRequest

myTrades ::
       MyTradesRequest
    -> BinanceUserApi (Either ClientError [MyTradesResponseLine])
myTrades params@MyTradesRequest {..} = do
    url <- asks url
    man <- asks managr
    pub <- asks publicKey
    let msg = urlEncodeAsForm params
    sig <- sign $ toStrict msg
    liftIO $
        runClientM
            (myTrades'
                 (Just pub)
                 (Just mtpSymbol)
                 mtpFromId
                 mtpLimit
                 mtpRecvWindow
                 (Just mtpTimestamp)
                 (Just ((pack . show) sig))) $
        ClientEnv man url Nothing -- defaultMakeClientRequest

account ::
       AccountRequest
    -> BinanceUserApi (Either ClientError AccountResponseStupid)
account params@AccountRequest {..} = do
    url <- asks url
    man <- asks managr
    pub <- asks publicKey
    let msg = urlEncodeAsForm params
    sig <- sign $ toStrict msg
    liftIO $
        runClientM
            (account'
                 (Just pub)
                 apRecvWindow
                 (Just apTimestamp)
                 (Just ((pack . show) sig))) $
        ClientEnv man url Nothing -- defaultMakeClientRequest

testOrder ::
       TestOrderRequest
    -> BinanceUserApi (Either ClientError Object)
testOrder params@TestOrderRequest{..} = do
    url <- asks url
    man <- asks managr
    pub <- asks publicKey
    let msg = urlEncodeAsForm params
    sig <- sign $ toStrict msg
    liftIO $
        runClientM
            (testOrder'
                 (Just pub)
                 params
                 (Just ((pack . show) sig))) $
        ClientEnv man url Nothing -- defaultMakeClientRequest


