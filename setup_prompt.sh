grep -qF 'run-parts /etc/update-motd.d/' ~/.bashrc || echo -e '\n# Show Armbian MOTD\nrun-parts /etc/update-motd.d/' >> ~/.bashrc
grep -qF 'systemctl status ttyd filebrowser nginx' ~/.bashrc || echo -e '\n# Show service status\nsystemctl status ttyd filebrowser nginx' >> ~/.bashrc
