
if [ -f /usr/local/nagios/libexec/utils.sh ]; then
  . /usr/local/nagios/libexec/utils.sh
else
  . /usr/lib/nagios/plugins/utils.sh
end

