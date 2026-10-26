package main

import "testing"

func TestAttestConfig(t *testing.T) {
	apns := map[string]string{"APNS_KEY_FILE": "/k", "APNS_KEY_ID": "K", "APNS_TEAM_ID": "ABCDE12345", "APNS_TOPIC": "com.byescaleira.fiscal.push-type.liveactivity"}
	c, err := loadConfig(envFrom(apns))
	if err != nil || c.attestMode != "optional" || c.attestAppID != "ABCDE12345.com.byescaleira.fiscal" || c.attestDev {
		t.Fatalf("derived = %+v %v", c, err)
	}
	off, err := loadConfig(envFrom(map[string]string{"APNS_DISABLED": "1"}))
	if err != nil || off.attestMode != "off" {
		t.Fatalf("without an app id = %+v %v", off, err)
	}
	for _, bad := range []map[string]string{
		{"APNS_DISABLED": "1", "APPATTEST_MODE": "required"},
		{"APNS_DISABLED": "1", "APPATTEST_MODE": "maybe"},
		{"APNS_DISABLED": "1", "APPATTEST_APP_ID": "nodot"},
		{"APNS_DISABLED": "1", "APPATTEST_APP_ID": "T.app", "APPATTEST_ALLOW_DEVELOPMENT": "yes"},
	} {
		if _, err := loadConfig(envFrom(bad)); err == nil {
			t.Errorf("%v must fail", bad)
		}
	}
	req, err := loadConfig(envFrom(map[string]string{"APNS_DISABLED": "1", "APPATTEST_APP_ID": "ABCDE12345.com.byescaleira.fiscal", "APPATTEST_MODE": "required", "APPATTEST_ALLOW_DEVELOPMENT": "1"}))
	if err != nil || req.attestMode != "required" || !req.attestDev {
		t.Fatalf("explicit = %+v %v", req, err)
	}
}
