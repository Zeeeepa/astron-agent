package handler

import (
	"errors"
	"github.com/gin-gonic/gin"
	"log"
	"net/http"
	"tenant/internal/models"
	"tenant/internal/service"
	"tenant/tools/generator"
)

type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) (*AuthHandler, error) {
	if authService == nil {
		return nil, errors.New("authService is nil")
	}
	return &AuthHandler{
		authService: authService,
	}, nil
}

func (handler *AuthHandler) ListAuth(c *gin.Context) {
	sid := c.GetString(keySid)
	appId := c.Param("app_id")
	auths, err := handler.authService.Query(appId)
	if err != nil {
		var appErr service.BizErr
		if errors.As(err, &appErr) {
			log.Printf("AuthList error: %v", appErr.Msg())
			resp := newErrResp(appErr.Code(), appErr.Msg(), sid)
			c.JSON(http.StatusOK, resp)
			return
		}
		log.Printf("request query auth by app_id[%s] error: %v", appId, err.Error())
		resp := newErrResp(service.ErrCodeSystem, err.Error(), sid)
		c.JSON(http.StatusOK, resp)
		return
	}
	if len(auths) == 0 {
		resp := newSuccessResp(nil, sid)
		c.JSON(http.StatusOK, resp)
		return
	}

	authDatas := make([]*AuthData, 0, len(auths))
	for _, item := range auths {
		data := &AuthData{
			ApiKey:    item.ApiKey,
			ApiSecret: item.ApiSecret,
		}
		authDatas = append(authDatas, data)
	}
	resp := newSuccessResp(authDatas, sid)
	c.JSON(http.StatusOK, resp)

}

func (handler *AuthHandler) SaveAuth(c *gin.Context) {
	sid := c.GetString(keySid)
	req, err := newAddAuthReq(c)
	if err != nil {
		log.Printf("build add auth request error: %v", err)
		resp := newErrResp(ParamErr, err.Error(), sid)
		c.JSON(http.StatusOK, resp)
		return
	}
	result, err := handler.authService.AddAuth(&models.Auth{
		AppId:      req.AppId,
		ApiKey:     req.ApiKey,
		ApiSecret:  req.ApiSecret,
		IsDelete:   false,
		CreateTime: generator.GenCurrTime(""),
		UpdateTime: generator.GenCurrTime(""),
	})

	if err != nil {
		var appErr service.BizErr
		if errors.As(err, &appErr) {
			log.Printf("request[%s] | sid[%s] add auth error: %s", req.RequestId, sid, appErr.Msg())
			resp := newErrResp(appErr.Code(), appErr.Msg(), sid)
			c.JSON(http.StatusOK, resp)
			return
		}

		log.Printf("request[%s] | sid[%s] add auth error: %s", req.RequestId, sid, err.Error())
		resp := newErrResp(service.ErrCodeSystem, err.Error(), sid)
		c.JSON(http.StatusOK, resp)
		return
	}
	resp := newSuccessResp(result, sid)
	c.JSON(http.StatusOK, resp)

}

func (handler *AuthHandler) DeleteAuth(c *gin.Context) {
	sid := c.GetString(keySid)
	req, err := newDeleteAuthReq(c)
	if err != nil {
		log.Printf("build delete auth request error: %v", err)
		resp := newErrResp(ParamErr, err.Error(), sid)
		c.JSON(http.StatusOK, resp)
		return
	}
	err = handler.authService.DeleteApiKey(req.AppId, req.ApiKey)
	if err != nil {
		var appErr service.BizErr
		if errors.As(err, &appErr) {
			log.Printf("request[%s] | sid[%s] delete auth error: %s", req.RequestId, sid, appErr.Msg())
			resp := newErrResp(appErr.Code(), appErr.Msg(), sid)
			c.JSON(http.StatusOK, resp)
			return
		}

		log.Printf("request[%s] | sid[%s] delete auth error: %s", req.RequestId, sid, err.Error())
		resp := newErrResp(service.ErrCodeSystem, err.Error(), sid)
		c.JSON(http.StatusOK, resp)
		return
	}

	resp := newSuccessResp(nil, sid)
	c.JSON(http.StatusOK, resp)

}
