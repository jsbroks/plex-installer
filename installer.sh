#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	echo "Sorry you are not root. (sudo ./installer.sh)"
	exit
fi

time_start=$(date +%s)

red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
purple='\e[1;35m'
gray='\e[0;37m'

local_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

SOURCE="${BASH_SOURCE[0]}"

while [ -h "$SOURCE" ]; do
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  	SOURCE="$(readlink "$SOURCE")"
  	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done

DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

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
	echo -ne "$gray$program $2\t "
	if ! dpkg -l $program &>>$LOGS ; then
		echo -e "${gray}[${red}Installing${gray}]"
		xterm -title "Installing $program" -e apt-get --yes install $program
	else 
		echo -e "${gray}[${green}OK${gray}]"
	fi
	sleep 0.25
}

copy () {
	cp $DIR/services/$1.service /lib/systemd/system/$1.service
}

header

echo -e "${green}Updating system...$gray"

#apt-get install -f -y
#apt-get autoremove -y
#apt-get clean -y

#apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
#echo "deb http://apt.sonarr.tv/ master main" >/etc/apt/sources.list.d/sonarr.list

#apt-get update
#apt-get install xterm --yes

clear

header

#xterm -title "Updating System" -e sudo apt-get upgrade -y
#xterm -title "Updating System" -e sudo apt-get dist-upgrade -y

install_pg python2.7
install_pg mono-complete
install_pg git '\t'
install_pg python-lxml
install_pg unzip '\t'
install_pg openssh-server
install_pg bzip2 '\t'
install_pg apache2
install_pg deluged
install_pg deluge-webui
install_pg nzbdrone

mkdir -p /opt/ProgramData/
cd /opt

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

#=============================

echo -en "${yellow}Installing Plex Media Server..." | tee -a $LOGS && echo "" >>$LOGS

plex_update="/opt/ProgramData/plexupdate/plexupdate.conf"
rm $plex_update >>$LOGS

xterm -title "Installing Plex" -e git clone https://github.com/mrworf/plexupdate.git
mkdir -p /opt/ProgramData/plexupdate/downloads >>$LOGS

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
	echo "DOWNLOADDIR='/opt/ProgramData/plexupdate/downloads'"
	echo "AUTOINSTALL=yes"
	echo "AUTODELETE=yes"
	echo "AUDOUPDATE=yes"
} >>$plex_update

xterm -title "Installing Plex" -e /opt/plexupdate/plexupdate.sh -f --config /opt/ProgramData/plexupdate/plexupdate.conf

(crontab -l >/dev/null ; echo "1 3 * * * /opt/plexupdate/plexupdate.sh --config /opt/ProgramData/plexupdate/plexupdate.conf")| crontab -

echo -e "$green\tDone"

#=============================

echo -en "${yellow}Installing Delgue..." | tee -a $LOGS && echo "" >>$LOGS

copy deluged
copy deluge-web

{
	adduser --disabled-password --system --home /var/lib/deluge --gecos "Deluge service" --group deluge
	touch /var/log/deluged.log
	touch /var/log/deluge-web.log
	chown deluge:deluge /var/log/deluge*

	systemctl start deluged
	systemctl enable deluged
	systemctl start deluge-web
	systemctl enable deluge-web
} &>>$LOGS

echo -e "$green\t\tDone"

#=============================

echo -en "${yellow}Installing CouchPotato..." | tee -a $LOGS && echo "" >>$LOGS

adduser --disabled-password --system --home /opt/ProgramData/couchpotato --gecos "CouchPotato service" --group couchpotato >>$LOGS
xterm -title "Installing CouchPotato" -e git clone https://github.com/CouchPotato/CouchPotatoServer.git
chown -R couchpotato:couchpotato /opt/CouchPotatoServer/

copy couchpotato

systemctl start couchpotato &>>$LOGS
systemctl enable couchpotato &>>$LOGS

echo -e "$green\tDone"

#=============================

echo -en "${yellow}Installing Sonarr..." | tee -a $LOGS && echo "" >>$LOGS

adduser --disabled-password --system --home /opt/ProgramData/sonarr --gecos "Sonarr Service" --group sonarr >>$LOGS

chown -R sonarr:sonarr /opt/NzbDrone

copy sonarr

systemctl start sonarr &>>$LOGS
systemctl enable sonarr &>>$LOGS

echo -e "$green\t\tDone"

#=============================

echo -en "${yellow}Installing PlexPy..." | tee -a $LOGS && echo "" >>$LOGS

adduser --disabled-password --system --no-create-home --gecos "PlexPy Service"  --group plexpy >>$LOGS
xterm -title "Installing PlexPy" -e git clone https://github.com/JonnyWong16/plexpy.git 

chown -R plexpy:plexpy /opt/plexpy

copy plexpy

systemctl start plexpy &>>$LOGS
systemctl enable plexpy &>>$LOGS

echo -e "$green\t\tDone"

#=============================

echo -en "${yellow}Installing PlexRequest.NET..." | tee -a $LOGS && echo "" >>$LOGS

mkdir /opt/ombi &>>$LOGS
cd /opt/ombi >>$LOGS

adduser --disabled-password --system --no-create-home --gecos "Ombi Service" --group ombi >>$LOGS
xterm -title "Installing PlexRequest.NET." -e wget $(curl -s https://api.github.com/repos/tidusjar/Ombi/releases/latest | grep 'browser_' | cut -d\" -f4)

unzip -o Ombi.zip >>$LOGS
rm Ombi.zip >>$LOGS

chown -R ombi:ombi /opt/ombi

copy ombi

systemctl start ombi &>>$LOGS
systemctl enable ombi &>>$LOGS

echo -e "$green\tDone"

#=============================

cp -rf $DIR/html/* /var/www/html/

#=============================

echo -e "\nEnter the follow URL into your web browser (must be on the same network)"
echo -e "\t${yellow}http://$local_ip/setup/ \n"