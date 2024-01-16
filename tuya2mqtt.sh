#!/bin/bash
ClientID="ujfuh33qcr7ghjmcyjwm"
ClientSecret="094a1234d320493795b7f497f68a24d9"
Device="bf4dd59qwe8353c962jvdy"
MQTTSERVER="192.168.10.2"
MQTTUSER="xxxx"
MQTTPASS="xxxx"

debug=false

# Declare constants

BaseUrl="https://openapi.tuyaeu.com"
EmptyBodyEncoded="e3b0c44298fc1c149afbf4c8996fb92222ae41e4649b934ca495991b7852b855"
tuyatime=`(date +%s)`
tuyatime=$tuyatime"000"
if ($debug) then echo Tuyatime is now $tuyatime; fi;


# Get Access Token

URL="/v1.0/token?grant_type=1"

StringToSign="${ClientID}${tuyatime}GET\n${EmptyBodyEncoded}\n\n${URL}"
if ($debug) then echo StringToSign is now $StringToSign; fi;

AccessTokenSign=$(printf $StringToSign | openssl sha256 -hmac  "$ClientSecret" | tr '[:lower:]' '[:upper:]' |sed "s/.* //g")
if ($debug) then echo AccessTokenSign is now $AccessTokenSign; fi;

AccessTokenResponse=$(curl -sSLkX GET "$BaseUrl$URL" -H "sign_method: HMAC-SHA256" -H "client_id: $ClientID" -H "t: $tuyatime"  -H "mode: cors" -H "Content-Type: application/json" -H "sign: $AccessTokenSign")
if ($debug) then echo AccessTokenResponse is now $AccessTokenResponse; fi;

AccessToken=$(echo $AccessTokenResponse | sed "s/.*\"access_token\":\"//g"  |sed "s/\".*//g")
if ($debug) then echo Access token is now $AccessToken; fi;

# Send Device status request

URL="/v1.0/iot-03/devices/status?device_ids=$Device"

StringToSign="${ClientID}${AccessToken}${tuyatime}GET\n${EmptyBodyEncoded}\n\n${URL}"
if ($debug) then echo StringToSign is now $StringToSign; fi;

RequestSign=$(printf $StringToSign | openssl sha256 -hmac  "$ClientSecret" | tr '[:lower:]' '[:upper:]' |sed "s/.* //g")
if ($debug) then echo RequestSign is now $RequestSign; fi;

RequestResponse=$(curl -sSLkX GET "$BaseUrl$URL" -H "sign_method: HMAC-SHA256" -H "client_id: $ClientID" -H "t: $tuyatime"  -H "mode: cors" -H "Content-Type: application/json" -H "sign: $RequestSign" -H "access_token: $AccessToken")
if ($debug) then echo RequestResponse is now $RequestResponse; fi

temp=$(echo $RequestResponse |  python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['result'][0]['status'][0]['value']);";);
temp=$(echo "scale=1; $temp/10" | bc);
humi=$(echo $RequestResponse |  python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['result'][0]['status'][1]['value']);";);
if (( $humi > 5 )); then
	mosquitto_pub -h $MQTTSERVER -u $MQTTUSER --pw $MQTTPASS -t temp -m $temp;
	sleep 2;
	mosquitto_pub -h $MQTTSERVER -u $MQTTUSER --pw $MQTTPASS -t humi -m $humi;
fi
