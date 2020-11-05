package cmd

import (
	"errors"
	"github.com/fatih/color"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
)

const (
	profileFilename = ".repustate"
)

var (
	usernameRegexp = regexp.MustCompile(`^\d*[a-zA-Z][a-zA-Z0-9_]*$`)
)

func loadUser() (string, error) {
	f := filepath.Join(getHomeDir(), profileFilename)
	data, err := ioutil.ReadFile(f)
	if err != nil {
		return "", err
	}

	username := string(data)
	if username == "" {
		return "", errors.New("user not registered")
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
		return errors.New("only alphanumeric values and '_' are allowed")
	}

	return nil
}

func colorBlue(s string) string {
	return color.New(color.FgBlue).Sprint(s)
}
func colorRed(s string) string {
	return color.New(color.FgRed).Sprint(s)
}
