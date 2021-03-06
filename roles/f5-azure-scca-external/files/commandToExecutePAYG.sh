function cp_logs() { 
    cd /var/lib/waagent/custom-script/download && cp `ls -r | head -1`/std* /var/log/cloud/azure; 
    cd /var/log/cloud/azure && cat stdout stderr > install.log;
 }; 

CLOUD_LIB_DIR=/config/cloud/azure/node_modules/@f5devcentral; 
mkdir -p $CLOUD_LIB_DIR && cp f5-cloud-libs.tar.gz* /config/cloud; 

mkdir -p /var/log/cloud/azure;

/usr/bin/install -m 400 /dev/null /config/cloud/.passwd; 
/usr/bin/install -b -m 755 /dev/null /config/verifyHash; 
/usr/bin/install -b -m 755 /dev/null /config/installCloudLibs.sh; 

IFS=', variables('singleQuote'), '%', variables('singleQuote'), '; 
echo -e ', variables('verifyHash'), ' >> /config/verifyHash; 
echo -e ', variables('installCloudLibs'), ' >> /config/installCloudLibs.sh; 
echo -e ', variables('installCustomConfig'), ' >> /config/customConfig.sh; 
unset IFS; 

bash /config/installCloudLibs.sh; 
source $CLOUD_LIB_DIR/f5-cloud-libs/scripts/util.sh; 
encrypt_secret ', variables('singleQuote'), variables('adminPasswordOrKey'), variables('singleQuote'), ' \"/config/cloud/.passwd\" true; 
$CLOUD_LIB_DIR/f5-cloud-libs/scripts/createUser.sh --user svc_user --password-file /config/cloud/.passwd --password-encrypted;

', variables('allowUsageAnalytics')[parameters('allowUsageAnalytics')].hashCmd, '; 
/usr/bin/f5-rest-node $CLOUD_LIB_DIR/f5-cloud-libs/scripts/onboard.js --output /var/log/cloud/azure/onboard.log --signal ONBOARD_DONE --log-level info --cloud azure --host ', variables('mgmtSubnetPrivateAddress'), ' --ssl-port ', variables('bigIpMgmtPort'), ' -u svc_user --password-url file:///config/cloud/.passwd --password-encrypted --hostname ', concat(variables('instanceName'), '.', variables('location'), '.cloudapp.azure.us'),  ' --ntp ', parameters('ntpServer'), ' --tz ', parameters('timeZone'), ' --db tmm.maxremoteloglength:2048', variables('allowUsageAnalytics')[parameters('allowUsageAnalytics')].metricsCmd, ' --module ltm:nominal; 
/usr/bin/f5-rest-node $CLOUD_LIB_DIR/f5-cloud-libs/scripts/network.js --output /var/log/cloud/azure/network.log --wait-for ONBOARD_DONE --host ', variables('mgmtSubnetPrivateAddress'), ' --port ', variables('bigIpMgmtPort'), ' -u svc_user --password-url file:///config/cloud/.passwd --password-encrypted --default-gw ', variables('tmmRouteGw'), ' --vlan name:external,nic:1.1 --vlan name:internal,nic:1.2 --self-ip name:self_2nic,address:', variables('extSubnetPrivateAddress'),  ',vlan:external --self-ip name:self_3nic,address:', variables('intSubnetPrivateAddress'),  ',vlan:internal --log-level info', '; 
if [[ $? == 0 ]]; 
then tmsh load sys application template f5.service_discovery.tmpl; 
tmsh load sys application template f5.cloud_logger.v1.0.0.tmpl; 
', variables('routeCmdArray')[parameters('bigIpVersion')], '; 
bash /config/customConfig.sh; 
$(cp_logs); 
else $(cp_logs); 
exit 1; 
fi', '; 
if grep -i \"PUT failed\" /var/log/waagent.log -q; 
then echo \"Killing waagent exthandler, daemon should restart it\"; 
pkill -f \"python -u /usr/sbin/waagent -run-exthandlers\"; 
fi