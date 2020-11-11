package cmd

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"

	"github.com/fatih/color"
)

const (
	profileFilename = ".repustate"
)

func loadUserUUID() string {
	f := filepath.Join(getHomeDir(), profileFilename)
	data, err := ioutil.ReadFile(f)
	if err != nil {
		return ""
	}

	return string(data)
}

func storeUserUUID(uuid string) error {
	filename := filepath.Join(getHomeDir(), profileFilename)

	f, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.WriteString(uuid)
	return err
}

func getHomeDir() string {
	dir, err := os.UserHomeDir()
	if err == nil {
		return dir
	}

	if runtime.GOOS == "windows" {
		home := os.Getenv("HOMEDRIVE") + os.Getenv("HOMEPATH")
		if home == "" {
			home = os.Getenv("USERPROFILE")
		}
		return home
	}
	return os.Getenv("HOME")
}

func printMsg(s string) {
	printColor(color.FgBlue, s)
}

func printErr(s string) {
	printColor(color.FgRed, s)
}

func printColor(c color.Attribute, s string) {
	color.New(c).Println(s)
}
