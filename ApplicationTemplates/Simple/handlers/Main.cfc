﻿<cfcomponent output="false" singleton>	<!--- Default Action --->	<cffunction name="index" returntype="void" output="false" hint="My main event">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">		<cfset prc.welcomeMessage = "Welcome to ColdBox!">		<cfset event.setView("main/index")>	</cffunction>	<!--- Do Something Action --->	<cffunction name="doSomething" returntype="void" output="false" hint="Do Something">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">		<cfset setNextEvent("main.index")>	</cffunction><!------------------------------------------- GLOBAL IMPLICIT EVENTS ONLY ------------------------------------------><!--- In order for these events to fire, you must declare them in the ColdBox.cfc --->	<cffunction name="onAppInit" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">	</cffunction>	<cffunction name="onRequestStart" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">	</cffunction>	<cffunction name="onRequestEnd" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">	</cffunction>	<cffunction name="onSessionStart" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">	</cffunction>	<cffunction name="onSessionEnd" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">		<cfset var sessionScope = event.getValue("sessionReference")>		<cfset var applicationScope = event.getValue("applicationReference")>	</cffunction>	<cffunction name="onException" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">		<cfscript>			//Grab Exception From private request collection, placed by ColdBox Exception Handling			var exception = prc.exception;			//Place exception handler below:		</cfscript>	</cffunction>	<cffunction name="onMissingTemplate" returntype="void" output="false">		<cfargument name="event">		<cfargument name="rc">		<cfargument name="prc">		<cfscript>			//Grab missingTemplate From request collection, placed by ColdBox			var missingTemplate = event.getValue("missingTemplate");		</cfscript>	</cffunction></cfcomponent>