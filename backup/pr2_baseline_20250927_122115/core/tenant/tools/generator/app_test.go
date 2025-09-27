package generator

import (
	"fmt"
	"testing"
)

func TestGenAppId(*testing.T) {
	id := GenAppId(8)
	fmt.Println(id)
}

func TestGenSecret(*testing.T) {
	secret := GenSecret()
	fmt.Println(secret)
}

func TestGenKey(*testing.T) {
	secret := GenKey("b4c897da")
	fmt.Println(secret)
}
