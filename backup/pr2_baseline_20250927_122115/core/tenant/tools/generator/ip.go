package generator

import (
	"fmt"
	"log"
	"net"
	"os"
	"runtime"
	"runtime/debug"
)

var IP string

func init() {
	ip, err := GetLocalIP()
	if err != nil {
		log.Printf("get local ip failed: %v,set local ip：127.0.0.1", err)
		ip = "127.0.0.1"
	}
	IP = ip
}

// GetLocalIP 根据本机 hostname
// 需要判断其是否为 IPv4 后再返回
func GetLocalIP() (string, error) {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("get local ip panic: %v,stack: %s", err, string(debug.Stack()))
		}
	}()
	if runtime.GOOS == "windows" {
		ip, err := getWinIP()

		if err != nil {
			return "", err
		}

		if isIpv4(ip) {
			return ip, nil
		}

		return "", fmt.Errorf("can't get ipv4 from dns in windows os")
	}

	hostname, err := os.Hostname()
	if err != nil {
		return "", err
	}

	addrs, err := net.LookupHost(hostname)

	if err != nil {
		return "", err
	}

	for _, addr := range addrs {
		if isIpv4(addr) {
			return addr, nil
		}
	}

	return "", fmt.Errorf("can't convert hostname -> %v to ipv4", hostname)
}

// isIpv4 check ip is ipv4
func isIpv4(ip string) bool {
	trial := net.ParseIP(ip)
	return trial.To4() != nil
}

func getWinIP() (string, error) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "", err
	}
	if conn == nil {
		return "", fmt.Errorf("nil conn")
	}
	defer func() {
		if err := conn.Close(); err != nil {
			log.Printf("close conn error: %v", err)
		}
	}()

	localAddr := conn.LocalAddr().(*net.UDPAddr)

	return localAddr.IP.String(), nil
}
