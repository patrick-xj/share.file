#!/bin/bash
# Dest: OpenVPN 客户端证书文件创建并合并为一个证书文件

APPS_DIR='/data/apps/openvpn'
EASY_SRA_DIR="${APPS_DIR}/easy-rsa/3/"
CLIENT_CERT_FILE_DIR="${APPS_DIR}/client_cert_file/"
OVPN_USER_INDEX="${APPS_DIR}/easy-rsa/3/pki/index.txt"
OVPN_REMOTE_IP='192.168.3.160'


# 判断是否为空参数
if [ -z $1 ]; then
    echo "参数为空,输入参数: ovpnuser。请将需要添加的用户名写入此参数文件中"
    exit 1
# 判断参数是否输入错误
elif [ $1 != 'ovpnuser' ]; then
    echo "参数输入错误,输入参数: ovpnuser。请将需要添加的用户名写入此参数文件中"
    exit 2
else
   OVPN_USER_FILE=$(cat ${APPS_DIR}/$1)
   [ ! -z "$CLIENT_CERT_FILE_DIR" ] && mkdir -p $CLIENT_CERT_FILE_DIR
fi

create_ovpn_cert() {
    cd ${EASY_SRA_DIR}
    spawn ./easyrsa build-client-full ${OVPN_USER}.inadm.com &> /dev/null
    expect {
        "^Enter PEM pass phrase" { send "inadm.com\r"; exp_continue }
        "^Verifying - Enter" { send "inadm.com\r"; exp_continue }
        "^Enter pass phrase" { send "inadm.com\r" }
    }
    expect eof
    echo -e "client\nproto tcp\nremote ${OVPN_REMOTE_IP}\nport 1202\ndev tun\nnobind\nremote-cert-tls server\n" >  ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn
    echo '<ca>' >>  ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; cat pki/ca.crt >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; echo '</ca>' >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn
    echo '<cert>' >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; cat pki/issued/${OVPN_USER}.crt >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; echo '</cert>' >>  ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn
    echo '<key>' >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; cat pki/private/${OVPN_USER}.key >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; echo '</key>' >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn
    echo '<tls-auth>' >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; grep -v '^#' ${APPS_DIR}/cert/ta.key >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn; echo -e "</tls-auth>\nkey-direction 1" >> ${CLIENT_CERT_FILE_DIR}/${OVPN_USER}.ovpn
    echo "${OVPN_USER} Create success."
    true > ${APPS_DIR}/ovpnuser
}

delete_ovpn_cert() {
    cd ${EASY_SRA_DIR}
    echo -e 'yes\n' | ./easyrsa revoke ${OVPN_USER} &> /dev/null
    ./easyrsa gen-crl &> /dev/null
    rm -f ${EASY_SRA_DIR}pki/issued/${OVPN_USER}.crt
    rm -f ${EASY_SRA_DIR}pki/private/${OVPN_USER}.key
    \cp ${EASY_SRA_DIR}pki/crl.pem ${APPS_DIR}/cert/
    echo "${OVPN_USER} Delete success."
    # 重启 openvpn 服务端注销生效,所有客户端会重新进行连接
    systemctl restart openvpn
    true > ${APPS_DIR}/ovpnuser
}

# 添加 openvpn 用户
add_user() {
    for OVPN_USER in ${OVPN_USER_FILE}; do
        # 查询用户用户名是否已存在
        EXISTED_USER=$(grep "$OVPN_USER" "$OVPN_USER_INDEX" | awk -F= '{print $2}')
        if [ -z $EXISTED_USER ]; then
            create_ovpn_cert
        else
            echo "${OVPN_USER} 用户已存在"
            exit 3
        fi
    done
}

# 删除 openvpn 用户
del_user() {
    for OVPN_USER in ${OVPN_USER_FILE} ;do
        delete_ovpn_cert
    done
}

PS3="Run command: "
select choice in add_user del_user exit; do
    case $choice in
        add_user)
           $choice
           exit
           ;;
        del_user)
           $choice
           exit
           ;;
        exit)
           echo "Bye~"
           exit
           ;;
    esac
done
