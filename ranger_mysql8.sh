#!/bin/bash
#配置参数
export DB_HOST=
export DB_ROOT_USER=admin
export DB_ROOT_PASSWORD=
export DB_NAME=rangerdb
export DB_USER=rangeradmin
export DB_PASSWORD=
export LDAP_HOST=
export LDAP_USER='cn=admin,dc=awsbuilder,dc=cn'
export LDAP_PASSWORD=
export S3_LOCATION=

#安装基础组件
yum -y install java-1.8* expect

echo 'export JAVA_HOME=/usr/lib/jvm/java' >>/etc/profile
echo 'export PATH=$JAVA_HOME/bin:$PATH' >>/etc/profile
source /etc/profile
sudo sh -c "echo 'net.ipv6.conf.all.disable_ipv6 = 1' >>/etc/sysctl.conf"
sudo sh -c "echo 'net.ipv6.conf.default.disable_ipv6 = 1' >>/etc/sysctl.conf"

wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-8.0.25.tar.gz
tar -zxf mysql-connector-java-8.0.25.tar.gz mysql-connector-java-8.0.25/mysql-connector-java-8.0.25.jar --strip-components 1
mv mysql-connector-java-8.0.25.jar /usr/share/java -f

wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
cat>keytool.sh<<EOF
#!/usr/bin/expect

spawn keytool -import -alias rds-root -keystore /usr/local/trustkeystore.jks -file global-bundle.pem
expect {
  "Enter keystore password:" {send "${DB_PASSWORD}\r"; exp_continue}
    "Re-enter new password: " {send "${DB_PASSWORD}\r"; exp_continue}
      "Trust this certificate? " {send "yes\r"}
}
expect eof
EOF
chmod 755 keytool.sh
./keytool.sh

aws s3 cp ${S3_LOCATION}/ranger-2.3.0-admin.tar.gz ./
aws s3 cp ${S3_LOCATION}/ranger-2.3.0-usersync.tar.gz ./
aws s3 cp ${S3_LOCATION}/ranger-2.3.0-hive-plugin.tar.gz ./
aws s3 cp ${S3_LOCATION}/ranger-2.3.0-trino-plugin.tar.gz ./
tar -zxf ranger-2.3.0-admin.tar.gz -C /usr/local
tar -zxf ranger-2.3.0-usersync.tar.gz -C /usr/local

#部署Ranger Admin 2.3
sed -i 's/SQL_CONNECTOR_JAR=\/usr\/share\/java\/mysql-connector-java.jar/SQL_CONNECTOR_JAR=\/usr\/share\/java\/mysql-connector-java-8.0.25.jar/g' /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_root_user=root/db_root_user='${DB_ROOT_USER}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_root_password=/db_root_password='${DB_ROOT_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_host=localhost/db_host='${DB_HOST}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_ssl_enabled=false/db_ssl_enabled=true/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_ssl_auth_type=2-way/db_ssl_auth_type=1-way/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/javax_net_ssl_trustStore=/javax_net_ssl_trustStore=\/usr\/local\/trustkeystore.jks/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/javax_net_ssl_trustStorePassword=/javax_net_ssl_trustStorePassword='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_name=ranger/db_name='${DB_NAME}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/db_password=/db_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/rangerAdmin_password=/rangerAdmin_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/rangerTagsync_password=/rangerTagsync_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/rangerUsersync_password=/rangerUsersync_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/keyadmin_password=/keyadmin_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/audit_store=solr/#audit_store=solr/g'  /usr/local/ranger-2.3.0-admin/install.properties
sed -i 's/varchar(4000)/varchar(3000)/g' /usr/local/ranger-2.3.0-admin/db/mysql/*.sql
sed -i 's/varchar(4000)/varchar(3000)/g' /usr/local/ranger-2.3.0-admin/db/mysql/optimized/current/*.sql
sed -i 's/varchar(4000)/varchar(3000)/g' /usr/local/ranger-2.3.0-admin/db/mysql/patches/*.sql
sed -i 's/4000/3000/g' /usr/local/ranger-2.3.0-admin/db/mysql/init/schema_mysql.sql

cd /usr/local/ranger-2.3.0-admin
./setup.sh
sleep 5
ranger-admin start
sleep 30

#部署Ranger UserSync 2.3
sed -i 's/POLICY_MGR_URL =/POLICY_MGR_URL = http:\/\/localhost:6080/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_SOURCE = unix/SYNC_SOURCE = ldap/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_INTERVAL =/SYNC_INTERVAL = 60/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/rangerUsersync_password=/rangerUsersync_password='${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_URL =/SYNC_LDAP_URL =ldap:\/\/'${LDAP_HOST}':389/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_BIND_DN =/SYNC_LDAP_BIND_DN ='${LDAP_USER}'/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_BIND_PASSWORD =/SYNC_LDAP_BIND_PASSWORD ='${LDAP_PASSWORD}'/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_DELTASYNC =/SYNC_LDAP_DELTASYNC =true/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_SEARCH_BASE =/SYNC_LDAP_SEARCH_BASE =dc=awsbuilder,dc=cn/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_LDAP_USER_SEARCH_BASE =/SYNC_LDAP_USER_SEARCH_BASE =dc=awsbuilder,dc=cn/g'  /usr/local/ranger-2.3.0-usersync/install.properties
sed -i 's/SYNC_GROUP_SEARCH_ENABLED=/SYNC_GROUP_SEARCH_ENABLED=false'${DB_PASSWORD}'/g'  /usr/local/ranger-2.3.0-usersync/install.properties
cd /usr/local/ranger-2.3.0-usersync
./setup.sh >setup.log
sed '8c\\t\t<value>true</value>' -i /usr/local/ranger-2.3.0-usersync/conf/ranger-ugsync-site.xml
sed '70c\\t\t<value>false</value>' -i /usr/local/ranger-2.3.0-usersync/conf/ranger-ugsync-default.xml
sleep 5
ranger-usersync start
sleep 30


#配置Ranger自动启动
echo '/usr/bin/ranger-admin start' >> /etc/rc.d/rc.local
echo '/usr/bin/ranger-usersync start' >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
