#!/bin/bash
###########################
##Name : Kunal Saxena     #
##TASK : Intall HelionCE  #
##Date : 17 Jul 2016      #
###########################

HCPCLI=" "
fileHCPCheck=" "
fileHCP=" "
linkHCP=" "
fileHSM=" "
linkHSM=" "
fileHCE=" "
hsm_url="hsm_url"

getvariables(){
HCPCLI=`grep HCPCLI stackato.conf | cut -d"|" -f2`
HCPCLIName=` grep HCPCLI stackato.conf | cut -d"|" -f2 | cut -d"/" -f5`

linkHCP=`grep linkHCP stackato.conf | cut -d"|" -f2`
fileHCPCheck=`grep linkHCP stackato.conf | cut -d"|" -f2 | cut -d"/" -f5 | sed 's/%2B/+/g'`

linkHSM=`grep linkHSM stackato.conf | cut -d"|" -f2`
fileHSM=`grep linkHSM stackato.conf | cut -d"|" -f2 | cut -d"/" -f9`

fileHCE=`grep fileHCE stackato.conf | cut -d"|" -f2`
}

createsetupFile(){
cd ~
touch setupFile
chmod 700 setupFile
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
        wget $linkHCP
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
echo "Download of HCP Bootstrap, HCP CLI and HSM is completed. "
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
chmod 400 ../*.pem
chmod 700 installStackato.sh
sudo dpkg -i $fileHCPCheck

bootstrap install ~/bootstrap.properties &
}

installHSM(){
cd ~
mkdir LOGs
gunzip $HCPCLIName
echo $HCPCLIName | cut -d"."  -f 1,2,3,4 > ~/LOGs/fileHSM_2
fileHCP_tar=`cat ~/LOGs/fileHSM_2`
tar -xvf $fileHCP_tar

logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hcp_url=`tail -10 $logfileName  | grep "HCP Service Location" | head -1 | cut -d ":" -f2,3,4 | awk '{print $1}'`
echo "HCP url: $hcp_url  "
echo "echo \" hcp api $hcp_url \" " >> ~/setupFile
echo "./hcp api $hcp_url" >> ~/setupFile
./hcp api $hcp_url
echo "echo \"hcp login admin@cnap.local -p cnapadmin\" " >> ~/setupFile
echo "./hcp login admin@cnap.local -p cnapadmin" >> ~/setupFile
./hcp login admin@cnap.local -p cnapadmin

gunzip $fileHSM
echo $fileHSM | cut -d"."  -f 1,2,3,4 > ~/LOGs/fileHSM_1
fileHSM_tar=`cat ~/LOGs/fileHSM_1`
tar -xvf $fileHSM_tar
logfileName=`ls -ltr bootstrap-* | tail -1 | awk '{print $9 }'`
hsm_url=`tail -10 $logfileName  | grep "Service Manager Location" | cut -d ":" -f2,3,4 | awk '{print $1}'`
echo "HSM url: $hsm_url  "
echo "Waiting for 10 sec before attaching end-point"
sleep 10

./hsm api $hsm_url
./hsm login --skip-ssl-validation -u admin@cnap.local -p cnapadmin
echo "echo \"hsm api $hsm_url\"  " >> ~/setupFile
echo "./hsm api $hsm_url" >> ~/setupFile
echo "echo \" hsm login --skip-ssl-validation -u admin@cnap.local -p cnapadmin \" " >> ~/setupFile
echo "./hsm login --skip-ssl-validation -u admin@cnap.local -p cnapadmin" >> ~/setupFile
sleep 5
./hsm update
./hsm version
./hsm list-instances
./hsm list-categories
./hsm list-services

./hcp add-user sax sax sax sax kunal.saxena@hpe.com --role=user
./hcp update-user sax -r=admin
./hcp update-user sax -r=publisher
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
echo "HCP url: hcp_url  "

./hcp api $hcp_url
./hcp login admin@cnap.local -p cnapadmin

./hsm login --skip-ssl-validation -u sax -p sax
./hsm create-instance hpe-catalog.hpe.hce -i hce_instance.json
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
echo "HCP url: hcp_url  "

./hcp api $hcp_url
./hcp login admin@cnap.local -p cnapadmin

./hsm login --skip-ssl-validation -u sax -p sax
./hsm create-instance hpe-catalog.hpe.hcf -i hcf_instance.json
}

attachHCE(){
echo "Attaching HCE endpoint .... " 
echo "-------------------------"
echo " "

#hce_instanceID=`./hsm list-instances | grep HPE | cut -d" " -f1`
#./hsm get-instance $hce_instanceID > result
echo "Once HCE installed enter HCE url, under tag hce-rest in loadbalancer"
echo "HCE url e.g. a68e464bf53d911e6b19402d8953fa2a-1548373400.eu-west-1.elb.amazonaws.com:"
read hce_url
echo "echo \"hce api --skip-ssl-validation http://$hce_url\" " >> ../setupFile	
echo "./hce api --skip-ssl-validation http://$hce_url" >> ../setupFile	
echo "enter username and password with sapce for HCE"
echo "user pwd:"
read UserPass
echo "echo \"hce login $UserPass\" "  >> ../setupFile
echo "./hce login $UserPass" >> ../setupFile	

#hce_url=`tail -n 6 result | grep IP | cut -d" " --complement -s -f1 | awk '{print $1}'`
cd 
tar -xvf $fileHCE
cp ~/linux/hce ~/.
./hce api http://$hce_url
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
Pmaster=`grep master ~/LOGs/Partial-* | cut -d":" -f1 | tail -1 `
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
echo "    3. Create Key and Property file  "
echo "    4. Download HCP, HSM  "
echo "    5. Install HSM "
echo "    6. Install HCE "
echo "    7. Install HCF "
echo "    8. Attach HCE endpoint"
echo "    9. Get Nodes IP"
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
                installHCF
        fi
        if [ "$input" = "8" ]; then
                attachHCE
        fi
        if [ "$input" = "9" ]; then
                getNodes
        fi        
        if [ "$input" = "E" ]; then
                exit
        fi
fi
}





main
