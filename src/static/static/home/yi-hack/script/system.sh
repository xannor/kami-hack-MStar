#!/bin/sh

CONF_FILE="etc/system.conf"

YI_HACK_PREFIX="/home/yi-hack"
YI_PREFIX="/home/app"

YI_HACK_VER=$(cat /home/yi-hack/version)
MODEL_SUFFIX=$(cat /home/yi-hack/model_suffix)

get_config()
{
    key=$1
    grep -w $1 $YI_HACK_PREFIX/$CONF_FILE | cut -d "=" -f2
}

start_buffer()
{
    # Trick to start circular buffer filling
    ./cloud &
    IDX=`hexdump -n 16 /dev/fshare_frame_buf | awk 'NR==1{print $8}'`
    N=0
    while [ "$IDX" -eq "0000" ] && [ $N -lt 60 ]; do
        IDX=`hexdump -n 16 /dev/fshare_frame_buf | awk 'NR==1{print $8}'`
        N=$(($N+1))
        sleep 0.2
    done
    killall cloud
    ipc_cmd -x
}

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/lib:/home/yi-hack/lib:/tmp/sd/yi-hack/lib
export PATH=$PATH:/home/base/tools:/home/yi-hack/bin:/home/yi-hack/sbin:/tmp/sd/yi-hack/bin:/tmp/sd/yi-hack/sbin

ulimit -s 1024

# Remove core files, if any
rm -f $YI_HACK_PREFIX/bin/core
rm -f $YI_PREFIX/core

if [ ! -L /home/yi-hack-v4 ]; then
    ln -s $YI_HACK_PREFIX /home/yi-hack-v4
fi

touch /tmp/httpd.conf

# Restore configuration after a firmware upgrade
if [ -f $YI_HACK_PREFIX/fw_upgrade_in_progress ]; then
    cp -f /tmp/sd/fw_upgrade/*.conf $YI_HACK_PREFIX/etc/
    chmod 0644 $YI_HACK_PREFIX/etc/*.conf
    if [ -f /tmp/sd/fw_upgrade/hostname ]; then
        cp -f /tmp/sd/fw_upgrade/hostname /etc/
        chmod 0644 /etc/hostname
    fi
    if [ -f /tmp/sd/fw_upgrade/TZ ]; then
        cp -f /tmp/sd/fw_upgrade/TZ /etc/
        chmod 0644 /etc/TZ
    fi
    rm $YI_HACK_PREFIX/fw_upgrade_in_progress
fi

$YI_HACK_PREFIX/script/check_conf.sh

hostname -F $YI_HACK_PREFIX/etc/hostname
export TZ=$(get_config TIMEZONE)

if [[ x$(get_config USERNAME) != "x" ]] ; then
    USERNAME=$(get_config USERNAME)
    PASSWORD=$(get_config PASSWORD)
    ONVIF_USERPWD="--user $USERNAME --password $PASSWORD"
    echo "/:$USERNAME:$PASSWORD" > /tmp/httpd.conf
fi

#PASSWORD_MD5='$1$$qRPK7m23GJusamGpoGLby/'
#if [[ x$(get_config SSH_PASSWORD) != "x" ]] ; then
#    SSH_PASSWORD=$(get_config SSH_PASSWORD)
#    PASSWORD_MD5="$(echo "${SSH_PASSWORD}" | mkpasswd --method=MD5 --stdin)"
#fi
#CUR_PASSWORD_MD5=$(awk -F":" '$1 != "" { print $2 } ' /etc/passwd)
#if [[ x$CUR_PASSWORD_MD5 != x$PASSWORD_MD5 ]] ; then
#    sed -i 's|^\(root:\)[^:]*:|root:'${PASSWORD_MD5}':|g' "/etc/passwd"
#fi
if [[ x$(get_config SSH_PASSWORD) != "x" ]] ; then
    SSH_PASSWORD=$(get_config SSH_PASSWORD)
    PASSWORD_MD5="$(echo "${SSH_PASSWORD}" | mkpasswd --method=MD5 --stdin)"
    cp -f "/etc/passwd" "/home/yi-hack/etc/passwd"
    sed -i 's|^root::|root:'${PASSWORD_MD5}':|g' "/home/yi-hack/etc/passwd"
    mount --bind "/home/yi-hack/etc/passwd" "/etc/passwd"
    cp -f "/etc/shadow" "/home/yi-hack/etc/shadow"
    sed -i 's|^root::|root:'${PASSWORD_MD5}':|g' "/home/yi-hack/etc/shadow"
    mount --bind "/home/yi-hack/etc/shadow" "/etc/shadow"
fi


case $(get_config RTSP_PORT) in
    ''|*[!0-9]*) RTSP_PORT=554 ;;
    *) RTSP_PORT=$(get_config RTSP_PORT) ;;
esac
case $(get_config ONVIF_PORT) in
    ''|*[!0-9]*) ONVIF_PORT=80 ;;
    *) ONVIF_PORT=$(get_config ONVIF_PORT) ;;
esac
case $(get_config HTTPD_PORT) in
    ''|*[!0-9]*) HTTPD_PORT=8080 ;;
    *) HTTPD_PORT=$(get_config HTTPD_PORT) ;;
esac

if [ ! -f $YI_PREFIX/cloudAPI_real ]; then
    mv $YI_PREFIX/cloudAPI $YI_PREFIX/cloudAPI_real
    cp $YI_HACK_PREFIX/script/cloudAPI $YI_PREFIX/
fi

if [[ $(get_config DISABLE_CLOUD) == "no" ]] ; then
    (
        cd /home/app
        if [[ $(get_config RTSP_AUDIO) == "no" ]] || [[ $(get_config RTSP_AUDIO) == "none" ]] ; then
            ./rmm &
            sleep 4
        else
            OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH="/home/yi-hack/lib:/lib:/home/lib:/home/ms:/home/app/locallib"
            ./rmm &
            export LD_LIBRARY_PATH=$OLD_LD_LIBRARY_PATH
            sleep 4
        fi
        ./mp4record &
        ./cloud &
        ./p2p_tnp &
        ./oss &
        if [ -f ./oss_fast ]; then
            ./oss_fast &
        fi
        if [ -f ./oss_lapse ]; then
            ./oss_lapse &
        fi
        ./watch_process &
    )
else
    (
        cd /home/app
        if [[ $(get_config RTSP_AUDIO) == "no" ]] || [[ $(get_config RTSP_AUDIO) == "none" ]] ; then
            ./rmm &
            sleep 4
        else
            OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH="/home/yi-hack/lib:/lib:/home/lib:/home/ms:/home/app/locallib"
            ./rmm &
            export LD_LIBRARY_PATH=$OLD_LD_LIBRARY_PATH
            sleep 4
        fi
        # Trick to start circular buffer filling
        start_buffer
        if [[ $(get_config REC_WITHOUT_CLOUD) == "yes" ]] ; then
            ./mp4record &
        fi
    )
fi

if [[ $(get_config HTTPD) == "yes" ]] ; then
    httpd -p $HTTPD_PORT -h $YI_HACK_PREFIX/www/ -c /tmp/httpd.conf
fi

if [[ $(get_config TELNETD) == "yes" ]] ; then
    telnetd
fi

if [[ $(get_config FTPD) == "yes" ]] ; then
    if [[ $(get_config BUSYBOX_FTPD) == "yes" ]] ; then
        tcpsvd -vE 0.0.0.0 21 ftpd -w &
    else
        pure-ftpd -B
    fi
fi

if [[ $(get_config SSHD) == "yes" ]] ; then
    mkdir -p $YI_HACK_PREFIX/etc/dropbear
    dropbear -R
fi

if [[ $(get_config NTPD) == "yes" ]] ; then
    # Wait until all the other processes have been initialized
    sleep 5 && ntpd -p $(get_config NTP_SERVER) &
fi

ipc_multiplexer &
sleep 1
if [[ $(get_config MQTT) == "yes" ]] ; then
    mqttv4 &
fi

sleep 5

if [[ $RTSP_PORT != "554" ]] ; then
    D_RTSP_PORT=:$RTSP_PORT
fi

if [[ $HTTPD_PORT != "80" ]] ; then
    D_HTTPD_PORT=:$HTTPD_PORT
fi

if [[ $ONVIF_PORT != "80" ]] ; then
    D_ONVIF_PORT=:$ONVIF_PORT
fi

if [[ $(get_config ONVIF_WM_SNAPSHOT) == "yes" ]] ; then
    WATERMARK="&watermark=yes"
fi

if [[ $(get_config RTSP) == "yes" ]] ; then
    if [[ $(get_config RTSP_AUDIO) == "no" ]] || [[ $(get_config RTSP_AUDIO) == "none" ]] ; then
        RTSP_EXE="rRTSPServer"
    else
        RTSP_EXE="rRTSPServer_audio"
    fi

    NR_LEVEL=$(get_config RTSP_AUDIO_NR_LEVEL)

    if [[ $(get_config RTSP_STREAM) == "low" ]]; then
        h264grabber_l -r low -f &
        sleep 1
        NR_LEVEL=$NR_LEVEL RRTSP_RES=1 RRTSP_PORT=$RTSP_PORT RRTSP_USER=$USERNAME RRTSP_PWD=$PASSWORD $RTSP_EXE &
        ONVIF_PROFILE_1="--name Profile_1 --width 640 --height 360 --url rtsp://%s$D_RTSP_PORT/ch0_1.h264 --snapurl http://%s$D_HTTPD_PORT/cgi-bin/snapshot.sh?res=low$WATERMARK --type H264"
    fi
    if [[ $(get_config RTSP_STREAM) == "high" ]]; then
        h264grabber_h -r high -f &
        sleep 1
        NR_LEVEL=$NR_LEVEL RRTSP_RES=0 RRTSP_PORT=$RTSP_PORT RRTSP_USER=$USERNAME RRTSP_PWD=$PASSWORD $RTSP_EXE &
        ONVIF_PROFILE_0="--name Profile_0 --width 1920 --height 1080 --url rtsp://%s$D_RTSP_PORT/ch0_0.h264 --snapurl http://%s$D_HTTPD_PORT/cgi-bin/snapshot.sh?res=high$WATERMARK --type H264"
    fi
    if [[ $(get_config RTSP_STREAM) == "both" ]]; then
        h264grabber_l -r low -f &
        h264grabber_h -r high -f &
        sleep 1
        NR_LEVEL=$NR_LEVEL RRTSP_RES=2 RRTSP_PORT=$RTSP_PORT RRTSP_USER=$USERNAME RRTSP_PWD=$PASSWORD $RTSP_EXE &
        if [[ $(get_config ONVIF_PROFILE) == "low" ]] || [[ $(get_config ONVIF_PROFILE) == "both" ]] ; then
            ONVIF_PROFILE_1="--name Profile_1 --width 640 --height 360 --url rtsp://%s$D_RTSP_PORT/ch0_1.h264 --snapurl http://%s$D_HTTPD_PORT/cgi-bin/snapshot.sh?res=low$WATERMARK --type H264"
        fi
        if [[ $(get_config ONVIF_PROFILE) == "high" ]] || [[ $(get_config ONVIF_PROFILE) == "both" ]] ; then
            ONVIF_PROFILE_0="--name Profile_0 --width 1920 --height 1080 --url rtsp://%s$D_RTSP_PORT/ch0_0.h264 --snapurl http://%s$D_HTTPD_PORT/cgi-bin/snapshot.sh?res=high$WATERMARK --type H264"
        fi
    fi
    $YI_HACK_PREFIX/script/wd_rtsp.sh &
fi

SERIAL_NUMBER=$(dd bs=1 count=20 skip=592 if=/tmp/mmap.info 2>/dev/null | cut -c1-20)
HW_ID=$(dd bs=1 count=4 skip=592 if=/tmp/mmap.info 2>/dev/null | cut -c1-4)

if [[ $(get_config ONVIF) == "yes" ]] ; then
    if [[ $MODEL_SUFFIX == "h201c" ]] ; then
        onvif_srvd --pid_file /var/run/onvif_srvd.pid --model "Yi Hack" --manufacturer "Yi" --firmware_ver "$YI_HACK_VER" --hardware_id $HW_ID --serial_num $SERIAL_NUMBER --ifs wlan0 --port $ONVIF_PORT --scope onvif://www.onvif.org/Profile/S $ONVIF_PROFILE_0 $ONVIF_PROFILE_1 $ONVIF_USERPWD --ptz --move_left "/home/yi-hack/bin/ipc_cmd -m left" --move_right "/home/yi-hack/bin/ipc_cmd -m right" --move_up "/home/yi-hack/bin/ipc_cmd -m up" --move_down "/home/yi-hack/bin/ipc_cmd -m down" --move_stop "/home/yi-hack/bin/ipc_cmd -m stop" --move_preset "/home/yi-hack/bin/ipc_cmd -p"
    else
        onvif_srvd --pid_file /var/run/onvif_srvd.pid --model "Yi Hack" --manufacturer "Yi" --firmware_ver "$YI_HACK_VER" --hardware_id $HW_ID --serial_num $SERIAL_NUMBER --ifs wlan0 --port $ONVIF_PORT --scope onvif://www.onvif.org/Profile/S $ONVIF_PROFILE_0 $ONVIF_PROFILE_1 $ONVIF_USERPWD
    fi
    if [[ $(get_config ONVIF_WSDD) == "yes" ]] ; then
        wsdd --if_name wlan0 --type tdn:NetworkVideoTransmitter --xaddr http://%s$D_ONVIF_PORT --scope "onvif://www.onvif.org/name/Unknown onvif://www.onvif.org/Profile/Streaming"
    fi
fi

FREE_SPACE=$(get_config FREE_SPACE)
if [[ $FREE_SPACE != "0" ]] ; then
    mkdir -p /var/spool/cron/crontabs/
    echo "  0  *  *  *  *  /home/yi-hack/script/clean_records.sh $FREE_SPACE" > /var/spool/cron/crontabs/root
    /usr/sbin/crond -c /var/spool/cron/crontabs/
fi

framefinder &

# Remove log files written to SD on boot containing the WiFi password
rm -f "/tmp/sd/log/log_first_login.tar.gz"
rm -f "/tmp/sd/log/log_login.tar.gz"
rm -f "/tmp/sd/log/log_p2p_clr.tar.gz"
rm -f "/tmp/sd/log/log_wifi_connected.tar.gz"

if [[ $(get_config FTP_UPLOAD) == "yes" ]] ; then
    /home/yi-hack/script/ftppush.sh start &
fi

if [ -f "/tmp/sd/yi-hack/startup.sh" ]; then
    /tmp/sd/yi-hack/startup.sh
fi
