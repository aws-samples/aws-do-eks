#!/bin/bash


curl -L -o ~/kube-ps1.sh https://github.com/jonmosco/kube-ps1/raw/master/kube-ps1.sh

cat << EOF >> ~/.bashrc
alias ll='ls -alh --color=auto'
alias kon='touch ~/.kubeon; source ~/.bashrc'
alias koff='rm -f ~/.kubeon; source ~/.bashrc'
alias kctl='kubectl'
alias k='kubectl'
alias kctx='kubectx'
alias kc='kubectx'
alias kn='kubens'
alias kns='kubens'
alias kt='kubetail'
alias ks='kubectl node-shell'
alias nsh='node-shell.sh'
alias nv='eks-node-viewer'
alias tx='torchx'
alias wkgp='watch-pods.sh'
alias wp='watch-pods.sh'
alias wkgn='watch-nodes.sh'
alias wn='watch-nodes.sh'
alias wkgnt='watch-node-types.sh'
alias wnt='watch-node-types.sh'
alias kgp='pods-list.sh'
alias lp='pods-list.sh'
alias kdp='pod-describe.sh'
alias kdn='nodes-describe.sh'
alias dp='pod-describe.sh'
alias dn='nodes-describe.sh'
alias kgn='nodes-list.sh'
alias lns='nodes-list.sh'
alias nl='nodes-list.sh'
alias kgnt='nodes-types-list.sh'
alias lnt='nodes-types-list.sh'
alias ntl='nodes-types-list.sh'
alias ke='pod-exec.sh'
alias pe='pod-exec.sh'
alias kl='kubectl stern'
alias pl='pod-logs.sh'
alias pln='pod-logs-ns.sh'
alias tf='terraform'
alias t='terraform'
alias cu='htop.sh'
alias gu='nvtop.sh'
alias nu='neurontop.sh'

if [ -f ~/.kubeon ]; then
        source ~/kube-ps1.sh
        PS1='[\u@\h \W \$(kube_ps1)]\$ '
fi

export TERM=xterm-256color

export PATH=$PATH:/root/go/bin:/root/.krew/bin:/eks/ops:.

EOF


