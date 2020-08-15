everyfile()
{
for file in $1/*
do
	if [ -d $file ]
	then
		#echo $file is diectory
		everyfile $file
	elif [ -f $file ]
	then
		#echo $file is file
		oldmd5=$(md5sum $file | awk {'print $1'})
		#echo $oldmd5
		if [ -f /$file ]
		then
			newmd5=$(md5sum /$file | awk {'print $1'})
			#echo file=$file, newmd5=$newmd5, oldmd5=$oldmd5
			if [ "$oldmd5" != "$newmd5" ]
			then
				cp $file /$file -P
				echo "update new file" $file
			fi
		fi
	else
		echo $file is not dir or file
	fi
done
}

echo "------------------------------------home app script update.sh enter------------------------------------"
######1.update base#################
if [ -f "/tmp/update/home/base/.basever" ]; then 
	newbasever=$(cat /tmp/update/home/base/.basever)
	if [ -f /home/base/.basever ]; then
		curbasever=$(cat /home/base/.basever)
	else
		echo /home/base/.basever not exist !!!
		curbasever=0
	fi
	
	echo basever, newbasever=$newbasever, curbasever=$curbasever
	if [ $newbasever != $curbasever ]
	then
		echo update base
		rm -rf /home/base/*
		cp -rfP /tmp/update/home/base/* /home/base
		sync
		cp /tmp/update/home/base/.basever /home/base/.basever
		sync
	fi
fi

######2.update app##################
if [ -f "/tmp/update/home/app/.appver" ]; then 
	newappver=$(cat /tmp/update/home/app/.appver)
	if [ -f /home/app/.appver ]; then
		curappver=$(cat /home/app/.appver)
	else
		echo /home/app/.appver not exist !!!
		curappver=0
	fi
	
	echo appver, newappver=$newappver, curappver=$curappver
	if [ $newappver != $curappver ]
	then
		echo update app
		rm -rf /home/app/*
		cp -rfP /tmp/update/home/app/* /home/app/
		sync
		cp /tmp/update/home/app/.appver /home/app/.appver
		sync
	fi
fi

######3.update lib############
if [ -f "/tmp/update/home/lib/.libver" ]; then 
	newlibver=$(cat /tmp/update/home/lib/.libver)
	if [ -f /home/lib/.libver ]; then
		curlibver=$(cat /home/lib/.libver)
	else
		echo /home/lib/.libver not exist !!!
		curlibver=0
	fi
	
	echo libver, newlibver=$newlibver, curlibver=$curlibver
	if [ $newlibver != $curlibver ]
	then
		echo update lib
		rm -rf /home/lib/*
		cp -rfP /tmp/update/home/lib/* /home/lib
		sync
		cp /tmp/update/home/lib/.libver /home/lib/.libver
		sync
	fi
fi

######4.update mstar######
if [ -f "/tmp/update/home/ms/.msver" ]; then 
	newmstarver=$(cat /tmp/update/home/ms/.msver)
	if [ -f /home/ms/.msver ]; then
		curmstarver=$(cat /home/ms/.msver)
	else
		echo /home/ms/.msver not exist !!!
		curmstarver=0
	fi
	
	echo msbver, newmstarver=$newmstarver, curmstarver=$curmstarver
	if [ $newmstarver != $curmstarver ]
	then
		echo update ms
		rm -rf /home/ms/*
		cp -rfP /tmp/update/home/ms/* /home/ms
		sync
		cp /tmp/update/home/ms/.msver /home/ms/.msver
		sync
	fi
fi

######5.update yi-hack######
hack_done=0
if [ -f "/tmp/update/home/yi-hack/version" ]; then 
	newyihackver=$(cat /tmp/update/home/yi-hack/version)

	if [ -f /home/yi-hack/version ]; then
		curyihackver=$(cat /home/yi-hack/version)
	else
		echo /home/yi-hack/version not exist !!!
		curyihackver=0
	fi

	echo yihackver, newyihackver=$newyihackver, curyihackver=$curyihackver
	echo update yi-hack
	mkdir -p /home/yi-hack
	rm -rf /home/yi-hack/*
	cp -rfP /tmp/update/home/yi-hack/* /home/yi-hack
	sync
	cp /tmp/update/home/yi-hack/version /home/yi-hack/version
	sync
	hack_done=1	
fi	

if [ -f /home/homever ]; then
	old_ver=$(cat /home/homever)
else
	old_ver=0
	echo /home/homever not exist, copy to it
	cp /tmp/update/home/homever /home/homever
fi

cd /tmp/update
echo check every file
everyfile home
sync
cd -

if [ $hack_done == 1 ]; then
	exit
fi

new_ver=$(cat /home/homever)

if [ $new_ver != $old_ver ]
then
	echo check pass
else
	echo check fail, why !!!, copy again
	rm -rf /home/homever
	cp /tmp/update/home/homever /home/homever
	sync
fi

#sync
echo "------------------------------------home app script update.sh exit------------------------------------"