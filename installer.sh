#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	echo "Sorry you are not root. (sudo ./installer.sh)"
	exit
fi

red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
purple='\e[1;35m'
gray='\e[0;37m'

local_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
DIR=$(dirname $0)
LOGS=$DIR/logs.txt

rm $LOGS >/dev/null
touch $LOGS

(date '+%A %W %Y %X') >$LOGS

header () {
	echo -e "$blue##################"
	echo -e "$blue#$red Plex Installer $blue#"
	echo -e "$blue##################\n"
}

install_pg () {
	program=$1
	echo -ne "$gray$program ... "
	condition=$(which $program 2>/dev/null | grep -v "not found" | wc -l)
	if [ $condition -eq 0 ] ; then
		echo -e "$gray""[$red""Installing""$gray""]"
		xterm -title "Installing $program" -e sudo apt-get --yes install $program
	else 
		echo -e "$gray""[$green""OK""$gray""]"
	fi
	sleep 0.1
}

header

echo -e "$green""Updating system...$gray"

#apt-get install -f -y
#apt-get autoremove -y
#apt-get clean -y

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
echo "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list

#apt-get update
#apt-get install xterm --yes

clear

header

#sudo xterm -title "Updating System" -e sudo apt-get upgrade -y
#sudo xterm -title "Updating System" -e sudo apt-get dist-upgrade -y

#install_pg python2.7
#install_pg mono-complete
install_pg git
#install_pg python-lxml
#install_pg python-zip
#install_pg unzip
#install_pg openssh-server
#install_pg libcurl4-openssh-dev
#install_pg bzip2
install_pg deluged
install_pg deluged-webui
install_pg nzbdrone

# Folder prep
mkdir -p /opt/ProgramData/
cd /opt/

clear

header
read -e -p 'Are you a plex pass owner [y/n]? ' plex_pass

if [ -z $plex_pass ] ; then
	plex_pass="n"
fi

if [ $plex_pass == "y" ] ; then
	read -p '  Plex Email: ' plex_email
	read -sp '  Plex Password: ' plex_password
	echo ""
else
	plex_pass="n"
fi

echo -en "$yellow""Installing Plex Media Server..." | tee -a $LOGS && echo "" >>$LOGS

plex_update="/opt/ProgramData/plexupdate/plexupdate.conf"

xterm -title "Installing Plex" -e git clone https://github.com/mrworf/plexupdate.git
mkdir -p /opt/ProgramData/plexupdate/downloads >>$LOGS
rm $plex_update >>$LOGS

if [ $plex_pass == "y" ] ; then
	{
		echo "USER='$plex_email'"
		echo "PASS='$plex_password'"
	} >$plex_update
else
	{
		echo "PUBLIC=yes"
	} >$plex_update
fi

{
	echo "DOWNLOADDIR='/opt/ProgramData/plexupdate/donwloads'"
	echo "AUTOINSTALL=yes"
	echo "AUTODELETE=yes"
	echo "AUDOUPDATE=yes"
} >>$plex_update

# CHECK FILE SO IT DOES NOT DUPLICATE
#(crontab -l >>$LOGS ; echo "1 3 * * * /opt/plexupdate/plexupdate.sh --config /opt/ProgramData/plexupdate/plexupdate.conf")| crontab -

echo -e "$green Done"

echo -en "$yellow""Installing Delgue..." | tee -a $LOGS && echo "" >>$LOGS
adduser --disabled-password --system --home /var/lib/deluge --gecos "Deluge service" --group deluge >>$LOGS
touch /var/log/deluged.log >>$LOGS
touch /var/log/deluge-web.log >>$LOGS
chown deluge:deluge /var/log/deluge* >>$LOGS

cp $DIR/services/deluged.service /lib/systemd/system/deluged.service
cp $DIR/services/deluge-web.service /lib/systemd/system/deluge-web.service

systemctl start deluged &>>$LOGS
systemctl enable deluged &>>$LOGS
systemctl start deluge-web &>>$LOGS
systemctl enable deluge-web &>>$LOGS

echo -e "$green Done"

echo -en "$yellow""Installing CouchPotato..." | tee -a $LOGS && echo "" >>$LOGS

adduser --disabled-password --system --home /opt/ProgramData/couchpotato --gecos "CouchPotato service" --group couchpotato >>$LOGS
xterm -title "Installing CouchPotato" -e git clone https://github.com/CouchPotato/CouchPotatoServer.git
chown -R couchpotato:couchpotato /opt/CouchPotatoServer/

cp $DIR/services/couchpotato.service /lib/systemd/system/couchpotato.service

systemctl start couchpotato &>>$LOGS
systemctl enable couchpotato &>>$LOGS

echo -e "$green Done"

echo -en "$yellow""Installing Sonarr..." | tee -a $LOGS && echo "" >>$LOGS

adduser --disabled-password --system --home /opt/ProgramData/sonarr --gecos "Sonarr Service" --group sonarr >>$LOGS

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC

echo "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list

sudo apt-get update && sudo apt-get install nzbdrone

sudo chown -R sonarr:sonarr /opt/NzbDrone

xterm -title "Installing CouchPotato" -e git clone https://github.com/CouchPotato/CouchPotatoServer.git 
chown -R couchpotato:couchpotato /opt/CouchPotatoServer/

cp $DIR/services/couchpotato.service /lib/systemd/system/couchpotato.service

systemctl start couchpotato &>>$LOGS
systemctl enable couchpotato &>>$LOGS

echo -e "$green Done"

#sensible-browser localhost >/dev/null
