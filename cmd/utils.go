package cmd

import (
	"errors"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"runtime"

	"github.com/fatih/color"
)

const (
	profileFilename = ".repustate"
)

var (
	usernameRegexp = regexp.MustCompile(`^\d*[a-zA-Z][a-zA-Z0-9_@\.]*$`)
)

func loadUser() (string, error) {
	f := filepath.Join(getHomeDir(), profileFilename)
	data, err := ioutil.ReadFile(f)
	if os.IsNotExist(err) {
		return "", errors.New("user not found")
	}
	if err != nil {
		return "", err
	}

	username := string(data)
	if username == "" {
		return "", errors.New("user not found")
	}

	return username, nil
}

func storeUser(u string) error {
	filename := filepath.Join(getHomeDir(), profileFilename)

	f, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.WriteString(u)
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

func validateUsername(u string) error {
	if !usernameRegexp.MatchString(u) {
		return errors.New("only alphanumeric values, '@' and '_' are allowed")
	}

	return nil
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
