#!/bin/bash
###########################
##Name : Kunal Saxena     #
##TASK : Intall HelionCE  #
##Date : 17 Jul 2016      #
###########################

fileHCPCheck=" "
fileHCP=" "
linkHCP=" "
fileHSM=" "
linkHSM=" "
fileHCE=" "
hsm_url="hsm_url"

getvariables(){
fileHCPCheck=`grep fileHCPCheck stackato.conf | cut -d"|" -f2`
fileHCP=`grep fileHCPCheck stackato.conf | cut -d"|" -f2 | sed 's/+/%2B/g'`
linkHCP=`grep linkHCP stackato.conf | cut -d"|" -f2`
linkHCP="$linkHCP$fileHCP"
fileHSM=`grep fileHSM stackato.conf | cut -d"|" -f2`
linkHSM=`grep linkHSM stackato.conf | cut -d"|" -f2`
linkHSM="$linkHSM$fileHSM"
fileHCE=`grep fileHCE stackato.conf | cut -d"|" -f2`
}

setup(){
sudo apt-get update
sudo apt-get install jq curl wget
sudo apt-get install genisoimage
sudo apt-get install awscli

echo " "
echo "======================================================================="
echo "Please copy following files before proceeding ...."
echo "  1. File Public Key (pem file) "
echo "  2. File bootstrap.properties " 
echo " " 
echo "Press enter when done ...." 
read abc

}

download(){
echo "Starting Download ....... "
echo " "
echo "Downloading HCP "
if [ -f "/home/ubuntu/$fileHCPCheck" ]
then
        echo "File $fileHCPCheck exist "
else
        wget $linkHCP
        mv hcp-bootstrap* ../
fi

sleep 2

echo " "
echo "Downloading HSM "
if [ -f "/home/ubuntu/$fileHSM" ]
then
        echo "File $fileHSM exist "
else
        wget $linkHSM
        mv hsm* ../
fi
echo " "
echo "Download of HCP and HSM is compelted. "
}

installHCP(){
echo "Installation of HCP .... " 
echo "-------------------------"
cd ..
sudo dpkg -i $fileHCPCheck

bootstrap install ~/bootstrap.properties &
}

installHSM(){
cd ..
gunzip $fileHSM
echo $fileHSM | cut -d"."  -f 1,2,3,4 > fileHSM_1
fileHSM_tar=`cat fileHSM_1`
tar -xvf $fileHSM_tar

hsm_url=`tail -10 bootstrap.log  | grep "Service Manager Location" | cut -d ":" -f2,3,4 | awk '{print $1}'`
echo "HSM url: $hsm_url  "

./hsm api $hsm_url
./hsm login --skip-ssl-validation -u admin@cnap.local -p cnapadmin

sleep 5
./hsm update
./hsm version
./hsm list-instances
./hsm list-categories
./hsm list-services
}


installHCE(){
echo "Installation of HCE .... " 
echo "-------------------------"
echo " "
echo "Transfer instance_hce.json file in jumpbox"
echo "Transfer HCE from windows"
echo "|    Login to each node VM separatly and  run folloiwing commands:"
echo "|    Commands:"
echo "|        sudo su"
echo "|        docker login"
echo "|        Run Command: for (( i=1; i<=1000 ;i++ )) ; do sleep 5 ;echo \"$i keeping awake ....\" ;done"
echo " " 
echo "Press enter when done ...." 
read abc

./hsm create-instance hpe-catalog.hpe.hce -i ~/instance_hce.json
}

attachHCE(){
echo "Attaching HCE endpoint .... " 
echo "-------------------------"
echo " "

hce_instanceID=`./hsm list-instances | grep HPE | cut -d" " -f1`
./hsm get-instance $hce_instanceID > result

hce_url=`tail -n 6 result | grep IP | cut -d" " --complement -s -f1 | awk '{print $1}'`
tar -xvf $fileHCE
cd linux
./hce api http://$hce_url:8080/v2
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


main(){
getvariables
echo "#############################################"
echo "      Welcome to HCP install                 "
echo "#############################################"

echo ""
echo "Select Option: "
echo "    1. Install HCP - scratch "
echo "    2. Install HCP "
echo "    3. Create Key and Property file  "
echo "    4. Download HCP, HSM  "
echo "    5. Install HSM "
echo "    6. Install HCE "
echo "    7. Attach HCE endpoint"

echo -n "    9. Exit   : (1/2/3) : "

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
                createInput
        fi
         if [ "$input" = "4" ]; then
                download
        fi
        if [ "$input" = "5" ]; then
                installHSM
        fi
        if [ "$input" = "6" ]; then
                installHCE
        fi
        if [ "$input" = "7" ]; then
                attachHCE
        fi

        if [ "$input" = "9" ]; then
                exit
        fi
fi
}





main
