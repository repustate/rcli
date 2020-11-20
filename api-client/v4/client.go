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
	basePath  = "demo"
	serverURL = "http://try.repustate.com:9000"
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

func (c *Client) Index(text, lang, user string) (*IndexResult, error) {
	q := url.Values{}
	q.Set("username", user)
	if lang != "" {
		q.Set("lang", lang)
	}

	data := map[string]interface{}{
		"text": text,
	}
	req, err := c.newRequest("index", http.MethodPost, q, data)
	if err != nil {
		return nil, err
	}

	body, err := requestDo(req)
	if err != nil {
		return nil, err
	}

	res := &IndexResult{}
	if err := json.Unmarshal(body, res); err != nil {
		return nil, err
	}

	return res, nil
}

func (c *Client) Search(query, user string) (*SearchResult, error) {
	q := url.Values{}
	q.Set("username", user)
	q.Set("query", query)

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
		return nil, fmt.Errorf("server responded %q", resp.Status)
	}

	return body, nil
}
