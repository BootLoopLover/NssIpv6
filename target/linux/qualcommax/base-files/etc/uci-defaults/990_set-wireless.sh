#!/bin/sh
. /usr/share/libubox/jshn.sh

echo "[+] Reset konfigurasi WiFi lama..."
uci delete wireless 2>/dev/null
uci commit wireless

BASE_SSID="AW1000"
COUNTRY="MY"
TXPOWER="auto"

# Kira berapa radio tersedia
RADIO_NUM=$(uci show wireless | grep -c "wifi-device")
[ "$RADIO_NUM" -eq 0 ] && {
    echo "[!] Tidak ada radio WiFi terdeteksi"
    exit 1
}

FIRST_5G=""

for i in $(seq 0 $((RADIO_NUM - 1))); do
    band=$(uci get wireless.radio${i}.band 2>/dev/null)
    path=$(uci get wireless.radio${i}.path 2>/dev/null)

    # Kalau band kosong, skip
    [ -z "$band" ] && continue

    echo "[+] Konfigurasi radio${i} (${band})..."

    # Reset config radio
    uci delete wireless.radio${i} 2>/dev/null
    uci delete wireless.default_radio${i} 2>/dev/null

    # Set default wifi-device
    uci set wireless.radio${i}='wifi-device'
    uci set wireless.radio${i}.type='mac80211'
    [ -n "$path" ] && uci set wireless.radio${i}.path="$path"
    uci set wireless.radio${i}.country="$COUNTRY"
    uci set wireless.radio${i}.txpower="$TXPOWER"
    uci set wireless.radio${i}.disabled='0'
    uci set wireless.radio${i}.cell_density='0'

    ssid="$BASE_SSID"

    case "$band" in
        "2g")
            uci set wireless.radio${i}.band='2g'
            uci set wireless.radio${i}.channel='11'
            uci set wireless.radio${i}.htmode='HE40'
            ssid="$BASE_SSID"
            ;;
        "5g")
            uci set wireless.radio${i}.band='5g'
            uci set wireless.radio${i}.channel='149'
            uci set wireless.radio${i}.htmode='HE80'
            if [ -z "$FIRST_5G" ]; then
                ssid="${BASE_SSID}_5G"
                FIRST_5G=1
            else
                ssid="${BASE_SSID}_5G-2"
            fi
            ;;
    esac

    # Set default wifi-iface
    uci set wireless.default_radio${i}='wifi-iface'
    uci set wireless.default_radio${i}.device="radio${i}"
    uci set wireless.default_radio${i}.network='lan'
    uci set wireless.default_radio${i}.mode='ap'
    uci set wireless.default_radio${i}.ssid="$ssid"
    uci set wireless.default_radio${i}.encryption='none'
    uci set wireless.default_radio${i}.ieee80211k='1'
    uci set wireless.default_radio${i}.bss_transition='1'

    echo "    • SSID=$ssid  |  Band=$band"
done

echo "[+] Menyimpan dan reload WiFi..."
uci commit wireless
wifi reload

echo "[✔️] Konfigurasi WiFi selesai!"
