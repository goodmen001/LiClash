package com.appshub.liclash;

import android.app.Application
import android.content.Context

class LiClashApplication : Application() {
    companion object {
        private lateinit var instance: LiClashApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}
