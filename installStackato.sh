#!/bin/bash
###########################
##Name : Kunal Saxena     #
##TASK : Intall HelionCE  #
##Date : 17 Jul 2016      #
###########################

HCPCLI=" "
fileHCPCheck=" "
fileHCP=" "
linkBootstrap=" "
fileHSM=" "
linkHSM=" "
fileHCE=" "
hsm_url="hsm_url"
domainname=""
dockuser=""
dockpass=""
gituser=""
gitpass=""
hcfversion=""
hceversion=""
consoleversion=""
clientID=""
clientSecret=""

getvariables(){
HCPCLI=`grep HCPCLI stackato.conf | cut -d"|" -f2`
HCPCLIName=` grep HCPCLI stackato.conf | cut -d"|" -f2 | cut -d"/" -f5`

linkBootstrap=`grep linkBootstrap stackato.conf | cut -d"|" -f2`
fileHCPCheck=`grep linkBootstrap stackato.conf | cut -d"|" -f2 | cut -d"/" -f5 | sed 's/%2B/+/g'`

linkHSM=`grep linkHSM stackato.conf | cut -d"|" -f2`
fileHSM=`grep linkHSM stackato.conf | cut -d"|" -f2 | cut -d"/" -f10`

fileHCE=`grep fileHCE stackato.conf | cut -d"|" -f2`

domainname=`grep domain stackato.conf | cut -d"|" -f2`

dockuser=`grep dockeruser stackato.conf | cut -d"|" -f2`
dockpass=`grep dockerpassword stackato.conf | cut -d"|" -f2`
gituser=`grep gituser stackato.conf | cut -d"|" -f2`
gitpass=`grep gitpass stackato.conf | cut -d"|" -f2`

clientID=`grep clientID stackato.conf | cut -d"|" -f2`
clientSecret=`grep clientSecret stackato.conf | cut -d"|" -f2`

hcfversion=`grep hcfversion stackato.conf | cut -d"|" -f2`
hceversion=`grep hceversion stackato.conf | cut -d"|" -f2`
consoleversion=`grep consoleversion stackato.conf | cut -d"|" -f2`
}

createsetupFile(){
cd ~
touch setupFile
chmod 700 setupFile
echo "export PATH=$PATH:/home/ubuntu" > setupFile
echo "github,https://github.com,$clientID,$clientSecret" > consolelogin
mkdir tar_ball
echo "exporting setup variables"

}
setup(){
sudo apt-get update
sudo apt-get install jq curl wget
sudo apt-get install genisoimage
sudo apt-get install awscli
createsetupFile
}

download(){
echo "Starting Download ....... "
echo " "
echo "Downloading HCP "
cd ~
if [ -f "/home/ubuntu/$fileHCPCheck" ]
then
        echo "File $fileHCPCheck exist "
else
        wget $linkBootstrap
fi

sleep 2

echo "Downloading HCP CLI "
hcpcli_tarname=`echo $HCPCLIName | cut -d"." -f1,2,3,4`
if [ -f "/home/ubuntu/$hcpcli_tarname" ] || [ -f "/home/ubuntu/$HCPCLIName" ]
then
        echo "File $hcpcli_tarname exist "
else
        wget $HCPCLI
fi

sleep 2

echo " "
echo "Downloading HSM "
hsmcli_tarname=`echo $fileHSM | cut -d"." -f1,2,3,4`
if [ -f "/home/ubuntu/$hsmcli_tarname" ] || [ -f "/home/ubuntu/$fileHSM" ]
then
        echo "File $hsmcli_tarname exist "
else
        wget $linkHSM
fi
echo " "
echo "Downloading CF CLI"
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx 

echo "Download of HCP Bootstrap, HCP CLI , CF and HSM is completed. "
}

installHCP(){
echo "Installation of HCP .... " 
echo "-------------------------"
cd ~
echo " "
echo "======================================================================="
echo "Please copy following files before proceeding ...."
echo "  1. File Public Key (pem file) "
echo "  2. File bootstrap.properties " 
echo " " 
echo "Press enter when done ...." 
read abc
chmod 400 *.pem
chmod 700 installStackato.sh
sudo dpkg -i $fileHCPCheck

bootstrap install ~/bootstrap.properties &
}

installHSM(){
cd ~
export PATH=$PATH:/home/ubuntu
mkdir LOGs
gunzip $HCPCLIName
echo $HCPCLIName | cut -d"."  -f 1,2,3,4 > ~/LOGs/fileHSM_2
fileHCP_tar=`cat ~/LOGs/fileHSM_2`
tar -xvf $fileHCP_tar

logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
echo "HCP url: $hcp_url  "
echo "echo \"Command: hcp api $hcp_url \" " >> ~/setupFile
echo "hcp api $hcp_url" >> ~/setupFile
hcp api $hcp_url
hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`
echo "echo \"Command: hcp login admin -p '$hcp_login' " >> ~/setupFile
echo "hcp login admin -p '$hcp_login' " >> ~/setupFile
hcp login admin -p "$hcp_login"

gunzip $fileHSM
echo $fileHSM | cut -d"."  -f 1,2,3,4 > ~/LOGs/fileHSM_1
fileHSM_tar=`cat ~/LOGs/fileHSM_1`
tar -xvf $fileHSM_tar
logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hsm_url=`tail -10 $logfileName  | grep "Service Manager Location" | cut -d ":" -f2,3,4 | awk '{print $1}'`
echo "HSM url: $hsm_url  "
echo "Waiting for 10 sec before attaching end-point"
sleep 10

echo "echo \"Command: hsm api --skip-ssl-validation $hsm_url\"  " >> ~/setupFile
echo "hsm api --skip-ssl-validation $hsm_url" >> ~/setupFile
hsm api --skip-ssl-validation $hsm_url

echo "echo \"Command: hsm login -u admin -p '$hcp_login' " >> ~/setupFile
echo "hsm login -u admin -p '$hcp_login' " >> ~/setupFile
hsm login -u admin -p "$hcp_login"

sleep 5
hsm update
hsm version
hsm list-instances
hsm list-categories
hsm list-services

hcp add-user sax sax sax sax kunal.saxena@hpe.com --role=user
hcp update-user sax -r=admin
hcp update-user sax -r=publisher
}

installServices(){
 echo "starting installation of HCF / HCE / Console"
 echo ""
 
 cp hcf_template.json ~/hcf_input.json
 cp hce_template.json ~/hce_input.json
 
 cd ~
 sed -i "s/\"DOMAIN\", \"value\": \"abcd\"/\"DOMAIN\", \"value\": \"$domainname\"/g" hcf_input.json
 sed -i "s/\"HCE_DOCKER_USERNAME\", \"value\": \"abcd\"/\"HCE_DOCKER_USERNAME\", \"value\": \"$dockuser\"/g" hce_input.json
 sed -i "s/\"HCE_DOCKER_PASSWORD\", \"value\": \"abcd\"/\"HCE_DOCKER_PASSWORD\", \"value\": \"$dockpass\"/g" hce_input.json

 logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
 hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
 hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`
 echo "HCP url: hcp_url  "

 ./hcp api $hcp_url
 ./hcp login admin -p "$hcp_login"

  echo "Starting HCF installation ...."
  echo "hsm create-instance hpe-catalog.hpe.hcf $hcfversion -i hcf_input.json"
  ./hsm create-instance hpe-catalog.hpe.hcf $hcfversion -i hcf_input.json
  
  sleep 6
  
  echo "Starting HCE installation ...."
  echo "hsm create-instance hpe-catalog.hpe.hce $hceversion -i hce_input.json"
  ./hsm create-instance hpe-catalog.hpe.hce $hceversion -i hce_input.json
 
  sleep 6
  echo "Starting Console installation ...."
  echo "hsm create-instance hpe-catalog.hpe.hsc $consoleversion -s < consolelogin"
  ./hsm create-instance hpe-catalog.hpe.hsc $consoleversion -s < consolelogin
 }
 
 
installHCE(){
echo "Installation of HCE .... " 
echo "-------------------------"
echo " "
echo "Transfer hce_instance.json file in jumpbox "
echo "Transfer HCE CLI from windows Check https://github.com/hpcloud/hce-cli/releases/"
echo "Press enter when done ...." 
read abc

cd ~
logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`
echo "HCP url: hcp_url  "
 cp hce_template.json ~/hce_input.json
 sed -i "s/\"HCE_DOCKER_USERNAME\", \"value\": \"abcd\"/\"HCE_DOCKER_USERNAME\", \"value\": \"$dockuser\"/g" hce_input.json
 sed -i "s/\"HCE_DOCKER_PASSWORD\", \"value\": \"abcd\"/\"HCE_DOCKER_PASSWORD\", \"value\": \"$dockpass\"/g" hce_input.json

./hcp api $hcp_url
./hcp login admin -p "$hcp_login"
  echo "hsm create-instance hpe-catalog.hpe.hce $hceversion -i hce_input.json"
  ./hsm create-instance hpe-catalog.hpe.hce $hceversion -i hce_input.json
}

installHCF(){
echo "Installation of HCF .... " 
echo "-------------------------"
echo " "
echo "Transfer hcf_instance.json file in jumpbox "
echo "Transfer hcf_sdl.json file in jumpbox"
echo "Press enter when done ...." 
read abc

cd ~
logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`
echo "HCP url: hcp_url  "
cp hcf_template.json ~/hcf_input.json
sed -i "s/\"DOMAIN\", \"value\": \"abcd\"/\"DOMAIN\", \"value\": \"$domainname\"/g" hcf_input.json 
./hcp api $hcp_url
./hcp login admin -p "$hcp_login"
  echo "hsm create-instance hpe-catalog.hpe.hcf $hcfversion -i hcf_input.json"
  ./hsm create-instance hpe-catalog.hpe.hcf $hcfversion -i hcf_input.json
}

installConsole(){
echo "Installation of Console .... " 
echo "-------------------------"
echo " "
cd ~
logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`
echo "HCP url: hcp_url  "

./hcp api $hcp_url
./hcp login admin -p "$hcp_login"

  echo "hsm create-instance hpe-catalog.hpe.hsc $consoleversion -s < consolelogin"
  ./hsm create-instance hpe-catalog.hpe.hsc $consoleversion -s < consolelogin
}

attachHCE(){
echo "Attaching HCE endpoint .... " 
echo "-------------------------"
echo " "
cd 
#hce_instanceID=`./hsm list-instances | grep HPE | cut -d" " -f1`
#./hsm get-instance $hce_instanceID > result
echo "Once HCE installed enter HCE url, under tag hce-rest in loadbalancer"
echo "HCE url e.g. a68e464bf53d911e6b19402d8953fa2a-1548373400.eu-west-1.elb.amazonaws.com:"
read hce_url
echo "echo \"hce api --skip-ssl-validation http://$hce_url\" " >> ../setupFile	
echo "./hce api --skip-ssl-validation http://$hce_url" >> ../setupFile	

logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
hcp_login=`grep "Admin credentials" $logfileName |  cut -d ":" -f2 | awk '{print $3}'`

echo "echo \"hce login admin $hcp_login \" "  >> ../setupFile
echo "./hce login admin $hcp_login" >> ../setupFile	

#hce_url=`tail -n 6 result | grep IP | cut -d" " --complement -s -f1 | awk '{print $1}'`

tar -xvf $fileHCE
./hce api --skip-ssl-validation http://$hce_url
./hce login admin $hcp_login
}

createPEM(){
echo "Validating Presence of Key ..."
echo "------------------------------"
filekey="AWS-Kunal.pem"
if [ -f "/home/ubuntu/$filekey" ]
then
        echo "$filekey exist "
else
	echo "Transfer pem file before proceeding ... " 
	echo " " 
	echo "Press enter when done ...." 
	read abc
fi
}

createbootstrapFile(){
echo "Creating bootstrap.properties ..."
fileBoot="bootstrap.properties"
if [ -f "/home/ubuntu/$fileBoot" ]
then
        echo "$fileBoot exist "
else
	echo "Transfer $fileBoot file before proceeding ... " 
	echo " " 
	echo "Press enter when done ...." 
	read abc
fi
}

createInput(){
createPEM
createbootstrapFile
}

getNodes(){
if [ -f "/home/ubuntu/awsParam" ] 
then
        echo "Please transfer awsParam with values "
        echo "awsParam is simple file with 4 values"
        echo "  1. AWS.AccessKey "
        echo "  2. AWS.SecretKey " 
        echo "  3. AWS.Region " 
        echo "  4. table "
else
        exit
fi

cd ~
aws configure < awsParam
mkdir -p ~/LOGs
aws ec2 describe-instances --filters "Name=key-name,Values=AWS-Kunal" > ~/LOGs/instances
rowF=`wc -l ~/LOGs/instances | cut -d" " -f1`
grep -n "   Instances     "  ~/LOGs/instances | cut -d":" -f1 > ~/LOGs/row_list
rowCount=`wc -l ~/LOGs/row_list | cut -d" " -f1`

cnt=0
First=""
cat ~/LOGs/row_list | while read line
do
   ((cnt++))
   First=$line
   if [ "$Last" !=  "" ]
   then
     Firstp="$Last","$First""p"
     sed -n $Firstp ~/LOGs/instances > ~/LOGs/Partial-$cnt
   fi
   if [ $cnt == $rowCount ]
   then
       rowFp="$First","$rowF""p"
       ((cnt++))
       sed -n $rowFp ~/LOGs/instances > ~/LOGs/Partial-$cnt
   fi
   Last=$First
done

echo "master" > ~/node_ip
Pmaster=`grep master ~/LOGs/Partial-* | cut -d":" -f1 | head -1 `
grep PrivateIpAddress $Pmaster  |  tail -1 | awk '{print $4}' >> ~/node_ip
echo "" >> ~/node_ip
echo "node" >> ~/node_ip
grep node- ~/LOGs/Partial-* | cut -d":" -f1 | while read line; do grep PrivateIpAddress $line | tail -1 | awk '{print $4}' ; done >> node_ip
echo ""
echo "Node Details : "
cat node_ip
}

main(){
getvariables
echo "#############################################"
echo "      Welcome to Stackato install            "
echo "#############################################"

echo ""
echo "Select Option: "
echo "    1. Install HCP - scratch "
echo "    2. Install HCP "
echo "    3. Get Nodes IP"
echo "    4. Install HSM "
echo "    5. Install All Services  "
echo "    6. Install HCE "
echo "    7. Install HCF "
echo "    8. Install Console "
echo "    9. Attach HCE endpoint"
echo -n "    E. Exit   : (1/2 or E) : "

read input
if [ -n $input ]; then
        echo "input is $input"
        if [ "$input" = "1" ]; then
                setup
                download
                createInput
                installHCP
        fi
        if [ "$input" = "2" ]; then
                installHCP
        fi
        if [ "$input" = "3" ]; then
                getNodes
        fi
         if [ "$input" = "4" ]; then
                installHSM
        fi
        if [ "$input" = "5" ]; then
                installServices
        fi
        if [ "$input" = "6" ]; then
                installHCE
        fi        
        if [ "$input" = "7" ]; then
                installHCF
        fi
        if [ "$input" = "8" ]; then
                installConsole
        fi
        if [ "$input" = "9" ]; then
                attachHCE
        fi        
        if [ "$input" = "E" ]; then
                exit
        fi
fi
}





main
