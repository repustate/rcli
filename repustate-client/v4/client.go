package v4

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"path"

	"github.com/pkg/errors"
)

const (
	apiVersion = "v4"
	basePath   = "demo"
	serverURL  = "http://try.repustate.com:9000"
)

type Client struct {
	serverAddr *url.URL
}

func New() (Client, error) {
	serverAddr, err := url.Parse(serverURL)
	if err != nil {
		return Client{}, errors.WithMessage(err, "bad server url address")
	}
	return Client{
		serverAddr: serverAddr,
	}, nil
}

func (c *Client) Register(user string) error {
	data := map[string]interface{}{
		"username": user,
	}
	req, err := c.newRequest("register", http.MethodPost, nil, data)
	if err != nil {
		return err
	}

	_, err = requestDo(req)
	return err
}

func (c *Client) Index(text, lang, user string) error {
	data := map[string]interface{}{
		"username": user,
		"text":     text,
	}
	q := url.Values{}
	if lang != "" {
		q["lang"] = []string{lang}
	}

	req, err := c.newRequest("index", http.MethodPost, q, data)
	if err != nil {
		return err
	}

	_, err = requestDo(req)
	return err
}

func (c *Client) Search(query, lang, user string) (*SearchResult, error) {
	q := url.Values{}
	q.Set("username", user)
	q.Set("query", query)
	if lang != "" {
		q.Set("lang", lang)
	}

	req, err := c.newRequest("search", http.MethodGet, q, nil)
	if err != nil {
		return nil, err
	}

	body, err := requestDo(req)
	if err != nil {
		return nil, err
	}

	res := &SearchResult{}
	if err := json.Unmarshal(body, res); err != nil {
		return nil, err
	}

	return res, nil
}

func (c *Client) newRequest(endpoint, method string, q url.Values, body interface{}) (*http.Request, error) {
	rel := &url.URL{Path: path.Join(basePath, endpoint)}
	u := c.serverAddr.ResolveReference(rel)
	buf := new(bytes.Buffer)
	if body != nil {
		err := json.NewEncoder(buf).Encode(body)
		if err != nil {
			return nil, err
		}
	}
	req, err := http.NewRequest(method, u.String(), buf)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Accept", "application/json; charset=utf-8")
	if q != nil {
		req.URL.RawQuery = q.Encode()
	}

	return req, nil
}

func requestDo(r *http.Request) ([]byte, error) {
	resp, err := http.DefaultClient.Do(r)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed execute request: %v - %v", resp.Status, string(body))
	}

	return body, nil
}
