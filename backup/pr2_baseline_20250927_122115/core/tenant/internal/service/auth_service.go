package service

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"tenant/internal/dao"
	"tenant/internal/models"
	"tenant/tools/generator"
)

type AuthService struct {
	appDao  *dao.AppDao
	authDao *dao.AuthDao
}

func NewAuthService(appDao *dao.AppDao, authDao *dao.AuthDao) (*AuthService, error) {
	if appDao == nil || authDao == nil {
		return nil, errors.New("appDao or authDao is nil")
	}
	return &AuthService{
		appDao:  appDao,
		authDao: authDao,
	}, nil
}

func (biz *AuthService) AddAuth(auth *models.Auth) (result *AddAuthResult, err error) {
	tx, err := biz.authDao.BeginTx()
	if err != nil {
		return
	}
	defer func() {
		biz.rollback(tx, err)
	}()
	appCount, err := biz.appDao.Count(true, tx, biz.appDao.WithAppId(auth.AppId), biz.appDao.WithIsDelete(false))
	if err != nil {
		log.Printf("call appDao.count error: %v", err)
		return
	}
	if appCount <= 0 {
		err = NewBizErr(AppIdNotExist, "request app_id not found")
		return
	}
	if len(auth.ApiKey) == 0 {
		auth.ApiKey = generator.GenKey(auth.AppId)
	}
	if len(auth.ApiSecret) == 0 {
		auth.ApiSecret = generator.GenSecret()
	}

	authCount, err := biz.authDao.Count(true, tx, //
		biz.authDao.WithApiKey(auth.ApiKey), biz.authDao.WithIsDelete(false))
	if err != nil {
		log.Printf("call authDao.count error: %v", err)
		return
	}
	if authCount > 0 {
		err = NewBizErr(ApiKeyHasExist, "api key has been exist")
		return
	}
	_, err = biz.authDao.Insert(auth, tx)
	if err != nil {
		return
	}
	result = &AddAuthResult{
		ApiKey:    auth.ApiKey,
		ApiSecret: auth.ApiSecret,
	}
	return
}

func (biz *AuthService) DeleteApiKey(appId string, apiKey string) (err error) {
	tx, err := biz.authDao.BeginTx()
	if err != nil {
		return
	}
	defer func() {
		biz.rollback(tx, err)
	}()
	appCount, err := biz.appDao.Count(true, tx, biz.appDao.WithAppId(appId), //
		biz.appDao.WithIsDelete(false))
	if err != nil {
		log.Printf("call appDao.count error: %v", err)
		return
	}
	if appCount <= 0 {
		err = NewBizErr(AppIdNotExist, "request app_id not found")
		return
	}
	rowNum, err := biz.authDao.Delete(tx, biz.authDao.WithApiKey(apiKey), biz.authDao.WithIsDelete(false))
	if err != nil {
		return
	}
	if rowNum == 0 {
		err = NewBizErr(ApiKeyNotExist, "api key not exist")
		return
	}
	return
}

func (biz *AuthService) Query(appId string) ([]*models.Auth, error) {
	data, err := biz.authDao.Select(biz.authDao.WithAppId(appId), biz.authDao.WithIsDelete(false))
	if err != nil {
		log.Printf("query auth biz info error: %v", err)
		return nil, NewBizErr(ErrCodeSystem, err.Error())
	}
	return data, nil
}

func (biz *AuthService) rollback(tx *sql.Tx, err error) {
	if r := recover(); r != nil {
		if err := tx.Rollback(); err != nil {
			fmt.Println("auth service rollback is panic", r)
			if err := tx.Rollback(); err != nil {
				log.Printf("failed to rollback tx: %v", err)
			}
		}
		return
	}
	if err != nil {
		if err := tx.Rollback(); err != nil {
			log.Printf("failed to rollback tx: %v", err)
		}
		return
	}
	if err := tx.Commit(); err != nil {
		log.Printf("failed to commit tx: %v", err)
	}
}
