package generator

import (
	"fmt"
	"testing"
)

func TestGenIP(*testing.T) {
	ip, err := GetLocalIP()
	if err != nil {
		panic(err)
	}
	fmt.Println("ip:", ip)
}
