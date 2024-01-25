#!/bin/bash

# This script installs Cloud9

# Install dev tools
if [ -d /etc/apt ]; then
  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y build-essential
else
  sudo yum -y groupinstall "Development Tools"
fi

# Install nodejs
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.0/install.sh | bash
source ~/.nvm/nvm.sh
source ~/.bashrc
nvm install 16.15.1
username=$(whoami)
if [ ! -f /usr/bin/node ]; then
        sudo ln -s /home/${username}/.nvm/versions/node/v16.15.1/bin/node /usr/bin/node
fi
node --version

# Install Cloud9 in /opt/c9
curl -o /tmp/install.sh -L https://raw.githubusercontent.com/c9/install/master/install.sh
chmod +x /tmp/install.sh
pushd /tmp
mkdir -p ~/.c9
./install.sh -d ~/.c9
popd

# Install tmux script
C9_HOME=~/.c9
if [ ! -d $C9_HOME ]; then
	C9_HOME=/opt/c9
fi

if [ -d $C9_HOME ]; then 
	sudo ln -s -f ${C9_HOME}/bin/tmux /usr/bin/tmux
fi

cat << EOF >> /tmp/cast
#!/bin/bash

panes=\$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}')

for p in \$panes; do
    #echo Sending command to pane: \$p;
    tmux send-keys -t \$p "\$1 \$2 \$3 \$4 \$5 \$6 \$7 \$8 \$8 \$9" Enter;
done

EOF

chmod +x /tmp/cast
sudo mv /tmp/cast /usr/bin/cast
sudo ln -s -f /usr/bin/cast /usr/bin/c

