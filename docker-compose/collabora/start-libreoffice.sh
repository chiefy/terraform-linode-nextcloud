#!/bin/sh

# Fix lool resolv.conf problem (wizdude)
rm /opt/lool/systemplate/etc/resolv.conf
ln -s /etc/resolv.conf /opt/lool/systemplate/etc/resolv.conf

# Replace trusted host and set admin username and password
perl -pi -e "s/localhost<\/host>/${domain}<\/host>/g" /etc/loolwsd/loolwsd.xml
perl -pi -e "s/<username desc=\"The username of the admin console. Must be set.\"><\/username>/<username desc=\"The username of the admin console. Must be set.\">${username}<\/username>/" /etc/loolwsd/loolwsd.xml
perl -pi -e "s/<password desc=\"The password of the admin console. Must be set.\"><\/password>/<password desc=\"The password of the admin console. Must be set.\">${password}<\/password>/g" /etc/loolwsd/loolwsd.xml
perl -pi -e "s/<server_name desc=\"Hostname:port of the server running loolwsd. If empty, it's derived from the request.\" type=\"string\" default=\"\"><\/server_name>/<server_name desc=\"Hostname:port of the server running loolwsd. If empty, it's derived from the request.\" type=\"string\" default=\"\">${server_name}<\/server_name>/g" /etc/loolwsd/loolwsd.xml

# Start loolwsd
su -c "/usr/bin/loolwsd \
--version \
--disable-ssl \
--o:sys_template_path=/opt/lool/systemplate \
--o:lo_template_path=/opt/collaboraoffice5.3 \
--o:child_root_path=/opt/lool/child-roots \
--o:file_server_root_path=/usr/share/loolwsd" \
-s /bin/bash lool
