#!/bin/bash
 
LANG=ja_JP.utf8
 
pid=$$
date=`date '+%Y-%m-%d-%H_%M'`

playerurl=http://radiko.jp/player/swf/player_4.1.0.00.swf
recmargin=1
recstartmargin=1

workdir="/tmp"

playerfile="${workdir}/pre_player.swf"
keyfile="${workdir}/pre_authkey.png"
cookiefile="${workdir}/pre_cookie_${pid}_${date}.txt"
loginfile="${workdir}/pre_login_${pid}_${date}.txt"
checkfile="${workdir}/pre_check_${pid}_${date}.txt"
logoutfile="${workdir}/pre_logout_${pid}_${date}.txt"

#-----radiko logout-----
Logout () {
   wget -q \
      --header="pragma: no-cache" \
      --header="Cache-Control: no-cache" \
      --header="Expires: Thu, 01 Jan 1970 00:00:00 GMT" \
      --header="Accept-Language: ja-jp" \
      --header="Accept-Encoding: gzip, deflate" \
      --header="Accept: application/json, text/javascript, */*; q=0.01" \
      --header="X-Requested-With: XMLHttpRequest" \
      --no-check-certificate \
      --load-cookies $cookiefile \
      --save-headers \
      -O $logoutfile \
      https://radiko.jp/ap/member/webapi/member/logout

   if [ -f $cookiefile ]; then
      rm -f $cookiefile
   fi
   echo "=== Logout: radiko.jp ==="
}

#-----args-----
if [ $# -le 1 ]; then
   echo "usage : $0 channel recminute [outputdir] [prefix] [mail] [password]"
   exit 1
fi

if [ $# -ge 2 ]; then
   channel=$1
   DURATION=`expr $2 \* 60 + ${recmargin} \* 2 \* 60 + ${recstartmargin} \* 60`
fi

outdir="."
if [ $# -ge 3 ]; then
   outdir=$3
fi

PREFIX=${channel}
if [ $# -ge 4 ]; then
   PREFIX=$4
fi

if [ $# -eq 5 ]; then
   echo "usage : $0 channel recminute [outputdir] [prefix] [mail] [password]"
   exit 1
fi

if [ $# -ge 6 ]; then
   mail=$5
   pass=$6
fi

#-----radiko premium-----
if [ $mail ]; then
   echo "-premium login(Get Cookie)-"
   wget -q --save-cookie=$cookiefile \
      --keep-session-cookies \
      --post-data="mail=$mail&pass=$pass" \
      -O $loginfile \
      https://radiko.jp/ap/member/login/login

   if [ ! -f $cookiefile ]; then
      echo "failed premium login"
      exit 1
   fi
fi

#-----check login-----
if [ $mail ]; then
   echo "-premium login-"
   wget -q \
      --header="pragma: no-cache" \
      --header="Cache-Control: no-cache" \
      --header="Expires: Thu, 01 Jan 1970 00:00:00 GMT" \
      --header="Accept-Language: ja-jp" \
      --header="Accept-Encoding: gzip, deflate" \
      --header="Accept: application/json, text/javascript, */*; q=0.01" \
      --header="X-Requested-With: XMLHttpRequest" \
      --no-check-certificate \
      --load-cookies $cookiefile \
      --save-headers \
      -O $checkfile \
      https://radiko.jp/ap/member/webapi/member/login/check

   if [ $? -ne 0 ]; then
      echo "failed premium login"
      exit 1
   fi
fi

#-----get player-----
if [ ! -f $playerfile ]; then
   echo "-get player-"
   wget -q -O $playerfile $playerurl

   if [ $? -ne 0 ]; then
      echo "failed get player"
      Logout
      exit 1
   fi
fi

#-----get keydata (with swftool)-----
if [ ! -f $keyfile ]; then
   echo "-get keydata-"
   swfextract -b 14 $playerfile -o $keyfile

   if [ ! -f $keyfile ]; then
      echo "failed get keydata"
      Logout
      exit 1
   fi
fi

#-----access auth1_fms-----
if [ -f auth1_fms_${pid} ]; then
   rm -f auth1_fms_${pid}
fi

if [ $mail ]; then
   wget -q \
      --header="pragma: no-cache" \
      --header="X-Radiko-App: pc_1" \
      --header="X-Radiko-App-Version: 2.0.1" \
      --header="X-Radiko-User: test-stream" \
      --header="X-Radiko-Device: pc" \
      --post-data='\r\n' \
      --no-check-certificate \
      --load-cookies $cookiefile \
      --save-headers \
      -O auth1_fms_${pid} \
      https://radiko.jp/v2/api/auth1_fms
else
   wget -q \
      --header="pragma: no-cache" \
      --header="X-Radiko-App: pc_1" \
      --header="X-Radiko-App-Version: 2.0.1" \
      --header="X-Radiko-User: test-stream" \
      --header="X-Radiko-Device: pc" \
      --post-data='\r\n' \
      --no-check-certificate \
      --save-headers \
      -O auth1_fms_${pid} \
      https://radiko.jp/v2/api/auth1_fms
fi

if [ $? -ne 0 ]; then
   echo "failed auth1 process"
   Logout
   exit 1
fi

#-----get partial key-----
authtoken=`perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)' auth1_fms_${pid}`
offset=`perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)' auth1_fms_${pid}`
length=`perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)' auth1_fms_${pid}`

partialkey=`dd if=$keyfile bs=1 skip=${offset} count=${length} 2> /dev/null | base64`

echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey: $partialkey"

rm -f auth1_fms_${pid}

#-----access auth2_fms-----
if [ -f auth2_fms_${pid} ]; then
   rm -f auth2_fms_${pid}
fi

if [ $mail ]; then
   wget -q \
      --header="pragma: no-cache" \
      --header="X-Radiko-App: pc_1" \
      --header="X-Radiko-App-Version: 2.0.1" \
      --header="X-Radiko-User: test-stream" \
      --header="X-Radiko-Device: pc" \
      --header="X-Radiko-Authtoken: ${authtoken}" \
      --header="X-Radiko-Partialkey: ${partialkey}" \
      --post-data='\r\n' \
      --load-cookies $cookiefile \
      --no-check-certificate \
      -O auth2_fms_${pid} \
      https://radiko.jp/v2/api/auth2_fms
else
   wget -q \
      --header="pragma: no-cache" \
      --header="X-Radiko-App: pc_1" \
      --header="X-Radiko-App-Version: 2.0.1" \
      --header="X-Radiko-User: test-stream" \
      --header="X-Radiko-Device: pc" \
      --header="X-Radiko-Authtoken: ${authtoken}" \
      --header="X-Radiko-Partialkey: ${partialkey}" \
      --post-data='\r\n' \
      --no-check-certificate \
      -O auth2_fms_${pid} \
      https://radiko.jp/v2/api/auth2_fms
fi

if [ $? -ne 0 -o ! -f auth2_fms_${pid} ]; then
   echo "failed auth2 process"
   Logout
   exit 1
fi

echo "authentication success"

areaid=`perl -ne 'print $1 if(/^([^,]+),/i)' auth2_fms_${pid}`
echo "areaid: $areaid"

rm -f auth2_fms_${pid}

#-----get stream-url-----
if [ -f ${channel}.xml ]; then
   rm -f ${channel}.xml
fi

wget -q "http://radiko.jp/v2/station/stream/${channel}.xml"

stream_url=`echo "cat /url/item[1]/text()" | xmllint --shell ${channel}.xml | tail -2 | head -1`
url_parts=(`echo ${stream_url} | perl -pe 's!^(.*)://(.*?)/(.*)/(.*?)$/!$1://$2 $3 $4!'`)

rm -f ${channel}.xml

#-----rtmpdump-----
rtmpdump -v \
      -r ${url_parts[0]} \
      --app ${url_parts[1]} \
      --playpath ${url_parts[2]} \
      -W $playerurl \
      -C S:"" -C S:"" -C S:"" -C S:$authtoken \
      --live \
      --stop ${DURATION} \
      --flv "${workdir}/${channel}_${date}"

#-----Logout-----
if [ $mail ]; then
   Logout
else
 :
fi

ffmpeg -loglevel quiet -y -i "${workdir}/${channel}_${date}" -acodec copy "${outdir}/${PREFIX}_${date}.aac"

if [ $? = 0 ]; then
   rm -f "/${workdir}/${channel}_${date}"
fi
