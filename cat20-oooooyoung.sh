Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}Інформація${Font_color_suffix}]"
Error="[${Red_font_prefix}Помилка${Font_color_suffix}]"
Tip="[${Green_font_prefix}Увага${Font_color_suffix}]"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} Ви не використовуєте ROOT аккаунт (або не маєте прав ROOT), не можна продовжувати операцію. Будь ласка, змініть аккаунт на ROOT або скористайтесь командою ${Green_background_prefix}sudo su${Font_color_suffix} для отримання тимчасових прав ROOT (після цього може бути запитано введення паролю поточного аккаунта)." && exit 1
}

install_env_and_full_node() {
    check_root
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential git make ncdu unzip zip docker.io -y
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    sudo apt-get install npm -y
    sudo npm install n -g
    sudo n stable
    sudo npm i -g yarn

    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    sudo yarn install
    sudo yarn build

    cd ./packages/tracker/
    sudo chmod 777 docker/data
    sudo chmod 777 docker/pgdata
    sudo docker-compose up -d

    cd ../../
    sudo docker build -t tracker:latest .
    sudo docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest
    echo '{
      "network": "fractal-mainnet",
      "tracker": "http://127.0.0.1:3000",
      "dataDir": ".",
      "maxFeeRate": 30,
      "rpc": {
          "url": "http://127.0.0.1:8332",
          "username": "bitcoin",
          "password": "opcatAwesome"
      }
    }' > ~/cat-token-box/packages/cli/config.json

    echo '#!/bin/bash

    command="sudo yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

    while true; do
        $command

        if [ $? -ne 0 ]; then
            echo "Команда виконана невдало, вихід із циклу"
            exit 1
        fi

        sleep 1
    done' > ~/cat-token-box/packages/cli/mint_script.sh
    chmod +x ~/cat-token-box/packages/cli/mint_script.sh
}

create_wallet() {
  echo -e "\n"
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet create
  echo -e "\n"
  sudo yarn cli wallet address
  echo -е "Збережіть створену адресу гаманця та мнемонічну фразу"
}

start_mint_cat() {
  read -p "Введіть бажану плату за mint: " newMaxFeeRate
  sed -i "s/\"maxFeeRate\": [0-9]*/\"maxFeeRate\": $newMaxFeeRate/" ~/cat-token-box/packages/cli/config.json
  cd ~/cat-token-box/packages/cli
  bash ~/cat-token-box/packages/cli/mint_script.sh
}

check_node_log() {
  docker logs -f --tail 100 tracker
}

check_wallet_balance() {
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet balances
}

echo && echo -e " ${Red_font_prefix}dusk_network Сценарій автоматичної установки${Font_color_suffix} by \033[1;35moooooyoung\033[0m
Цей сценарій є повністю безкоштовним і відкритим, розроблений користувачем Twitter ${Green_font_prefix}@ouyoung11${Font_color_suffix}, 
Не платіть, якщо вам пропонують за це гроші.
 ———————————————————————
 ${Green_font_prefix} 1. Встановити залежності та повний вузол ${Font_color_suffix}
 ${Green_font_prefix} 2. Створити гаманець ${Font_color_suffix}
 ${Green_font_prefix} 3. Почати майнінг CAT ${Font_color_suffix}
 ${Green_font_prefix} 4. Переглянути лог синхронізації вузла ${Font_color_suffix}
 ${Green_font_prefix} 5. Перевірити баланс гаманця ${Font_color_suffix}
 ———————————————————————" && echo
read -e -p " Будь ласка, виберіть дію, введіть номер:" num
case "$num" in
1)
    install_env_and_full_node
    ;;
2)
    create_wallet
    ;;
3)
    start_mint_cat
    ;;
4)
    check_node_log
    ;;
5)
    check_wallet_balance
    ;;
*)
    echo
    echo -e " ${Error} Введіть правильний номер"
    ;;
esac
