package generator

import (
	"fmt"
	"testing"
)

func TestSidGenerator(*testing.T) {
	sg := &SidGenerator2{}
	sg.Init("cn", "127.0.0.1", "8080")
	sid, err := sg.NewSid("test")
	if err != nil {
		panic(err)
	}
	fmt.Println("sid:", sid)
}
