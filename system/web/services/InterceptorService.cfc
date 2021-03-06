﻿/**
* Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
* www.ortussolutions.com
* ---
* This service takes care of all events and interceptions in ColdBox
*/
component extends="coldbox.system.web.services.BaseService" accessors="true"{
	
	/**
	 * Interception Points which can be announced
	 */
	property name="interceptionPoints" type="array";

	/**
	 * Interception States that represent the unique points
	 */
	property name="interceptionStates" type="struct";

	/**
	 * Interceptor Service Configuration
	 */
	property name="interceptorConfig" type="struct";

	// Interceptor base class
	INTERCEPTOR_BASE_CLASS = "coldbox.system.Interceptor";

	/**
	 * Constructor
	 */
	InterceptorService function init( required controller ){
		setController( arguments.controller );

		// Register the interception points ENUM
		variables.interceptionPoints = [
			// Application startup points
			"afterConfigurationLoad", "afterAspectsLoad", "preReinit",
			// On Actions
			"onException", "onRequestCapture", "onInvalidEvent",
			// After FW Object Creations
			"afterHandlerCreation", "afterInstanceCreation",
			// Life-cycle
			"applicationEnd" , "sessionStart", "sessionEnd", "preProcess", "preEvent", "postEvent", "postProcess", "preProxyResults",
			// Layout-View Events
			"preLayout", "preRender", "postRender", "preViewRender", "postViewRender", "preLayoutRender", "postLayoutRender", "afterRendererInit",
			// Module Events
			"preModuleLoad", "postModuleLoad", "preModuleUnload", "postModuleUnload", "preModuleRegistration", "postModuleRegistration",
			// Module Global Events
			"afterModuleRegistrations", "afterModuleActivations"
		];

		// Init Container of interception states
		variables.interceptionStates = {};
		// Default Logging
		variables.log = controller.getLogBox().getLogger( this );
		// Setup Default Configuration
		variables.interceptorConfig = {};

		return this;
	}

	/**
	 * Configure the service
	 */
	InterceptorService function configure(){
		// Reconfigure Logging With Application Configuration Data
		variables.log = controller.getLogBox().getLogger( this );
		// Setup Configuration
		variables.interceptorConfig = controller.getSetting( "InterceptorConfig" );
		// Register CFC Configuration Object
		registerInterceptor(
			interceptorObject 	= controller.getSetting( 'coldboxConfig' ), 
			interceptorName 	= "coldboxConfig"
		);

		return this;
	}

	/**
	 * Run once config loads
	 * 
	 * @return InterceptorService
	 */
	function onConfigurationLoad(){
		// Register All Application Interceptors
		registerInterceptors();
		return this;
	}

	/**
	 * Registers all the interceptors configured
	 * 
	 * @return InterceptorService
	 */
	function registerInterceptors(){
		// if simple, inflate
		if( isSimpleValue( variables.interceptorConfig.customInterceptionPoints ) ){
			variables.interceptorConfig.customInterceptionPoints = listToArray( variables.interceptorConfig.customInterceptionPoints );
		}

		// Check if we have custom interception points, and register them if we do
		if( arrayLen( variables.interceptorConfig.customInterceptionPoints ) ){
			appendInterceptionPoints( variables.interceptorConfig.customInterceptionPoints );
			// Debug log
			if( variables.log.canDebug() ){
				variables.log.debug( "Registering custom interception points: #variables.interceptorConfig.customInterceptionPoints.toString()#" );
			}
		}

		// Loop over the Interceptor Array, to begin registration
		var iLen = arrayLen( variables.interceptorConfig.interceptors );
		for( var x=1; x lte iLen; x++ ){
			registerInterceptor(
				interceptorClass      = variables.interceptorConfig.interceptors[ x ].class,
				interceptorProperties = variables.interceptorConfig.interceptors[ x ].properties,
				interceptorName       = variables.interceptorConfig.interceptors[ x ].name
			);
		}

		return this;
	}

	/**
	* Process a State's Interceptors
	* Announce an interception to the system. If you use the asynchronous facilities, you will get a thread structure report as a result.
	*
	* This is needed so interceptors can write to the page output buffer 
	* @output true
	*
	* @state An interception state to process
	* @interceptData A data structure used to pass intercepted information.
	* @async If true, the entire interception chain will be ran in a separate thread.
	* @asyncAll If true, each interceptor in the interception chain will be ran in a separate thread and then joined together at the end.
	* @asyncAllJoin If true, each interceptor in the interception chain will be ran in a separate thread and joined together at the end by default.  If you set this flag to false then there will be no joining and waiting for the threads to finalize.
	* @asyncPriority The thread priority to be used. Either LOW, NORMAL or HIGH. The default value is NORMAL
	* @asyncJoinTimeout The timeout in milliseconds for the join thread to wait for interceptor threads to finish.  By default there is no timeout
	*/
	public any function processState( 
		required any state,
		any interceptData=structNew(),
		boolean async=false,
		boolean asyncAll=false,
		boolean asyncAllJoin=true,
		string asyncPriority='NORMAL',
		numeric asyncJoinTimeout=0 
	){
		// Validate Incoming State
		if( variables.interceptorConfig.throwOnInvalidStates AND NOT 
			listFindNoCase( arrayToList( variables.interceptionPoints ), arguments.state ) 
		){
			throw( 
				message = "The interception state sent in to process is not valid: #arguments.state#", 
				detail 	= "Valid states are #variables.interceptionPoints.toString()#", 
				type 	= "InterceptorService.InvalidInterceptionState"
			);
		}

		// Init the Request Buffer
		var requestBuffer = new coldbox.system.core.util.RequestBuffer();

		// Process The State if it exists, else just exit out
		if( structKeyExists( variables.interceptionStates, arguments.state ) ){
			// Execute Interception in the state object
			arguments.event 	= controller.getRequestService().getContext();
			arguments.buffer 	= requestBuffer;
			var results 		= structFind( variables.interceptionStates, arguments.state ).process( argumentCollection=arguments );
		}

		// Process Output Buffer: looks weird, but we are outputting stuff and CF loves its whitespace
		if( requestBuffer.isBufferInScope() ) {
			writeOutput( requestBuffer.getString() );
			requestBuffer.clear();
		}
		
		// Any results
		if( !isNull( results ) ){
			return results;
		}
	}

	/**
	 * Register a new interceptor in ColdBox
	 *
	 * @interceptorClass Mutex with interceptorObject, this is the qualified class of the interceptor to register
	 * @interceptorObject Mutex with interceptor Class, this is used to register an already instantiated object as an interceptor
	 * @interceptorProperties The structure of properties to register this interceptor with.
	 * @customPoints A comma delimmited list or array of custom interception points, if the object or class sent in observes them.
	 * @interceptorName The name to use for the interceptor when stored. If not used, we will use the name found in the object's class
	 * 
	 * @return InterceptorService
	 */
	function registerInterceptor(
		interceptorClass,
		interceptorObject,
		struct interceptorProperties={},
		customPoints="",
		interceptorName
	){
		// determine registration names
		var objectName		= "";
		var oInterceptor 	= "";
		if( structKeyExists( arguments, "interceptorClass" ) ){
			objectName = listLast( arguments.interceptorClass, "." );
			if( structKeyExists( arguments, "interceptorName" ) ){
				objectName = arguments.interceptorName;
			}
		}
		else if( structKeyExists( arguments, "interceptorObject" ) ){
			objectName = listLast( getMetaData( arguments.interceptorObject ).name, "." );
			if( structKeyExists( arguments, "interceptorName" ) ){
				objectName = arguments.interceptorName;
			}
			oInterceptor = arguments.interceptorObject;
		} else {
			throw( 
				message = "Invalid registration.",
				detail  = "You did not send in an interceptorClass or interceptorObject argument for registration",
				type    = "InterceptorService.InvalidRegistration" 
			);
		}

		lock 	name="interceptorService.#getController().getAppHash()#.registerInterceptor.#objectName#" 
				type="exclusive" 
				throwontimeout="true" 
				timeout="30"
		{
			// Did we send in a class to instantiate
			if( structKeyExists( arguments, "interceptorClass" ) ){
				// Create the Interceptor Class
				try{
					oInterceptor = createInterceptor( interceptorClass, objectName, interceptorProperties );
				} catch( Any e ){
					variables.log.error( "Error creating interceptor: #arguments.interceptorClass#. #e.detail# #e.message# #e.stackTrace#", e.tagContext );
					rethrow;
				}

				// Configure the Interceptor
				oInterceptor.configure();

			}//end if class is sent.

			// Append Custom Points
			appendInterceptionPoints( arguments.customPoints );

			// Parse Interception Points
			var interceptionPointsFound = {};
			interceptionPointsFound 	= parseMetadata( getMetaData( oInterceptor ), interceptionPointsFound );

			// Register this Interceptor's interception point with its appropriate interceptor state
			for( var stateKey in interceptionPointsFound ){
				// Register the point
				registerInterceptionPoint(
					interceptorKey = objectName,
					state          = stateKey,
					oInterceptor   = oInterceptor,
					interceptorMD  = interceptionPointsFound[ stateKey ]
				);
				// Debug log
				if( variables.log.canDebug() ){
					variables.log.debug( "Registering #objectName# on '#statekey#' interception point" );
				}
			}
		} // end lock

		return this;
	}

	/**
	 * Create a new interceptor object with ColdBox pizzaz
	 *
	 * @interceptorClass The class path to instantiate
	 * @interceptorName The unique name of the object
	 * @interceptorProperties Construction properties
	 * 
	 * @return The newly created interceptor
	 */
	function createInterceptor(
		required interceptorClass,
		required interceptorName,
		struct interceptorProperties={}
	){
		var wirebox = controller.getWireBox();

		// Check if interceptor mapped?
		if( NOT wirebox.getBinder().mappingExists( "interceptor-" & arguments.interceptorName ) ){
			// wirebox lazy load checks
			wireboxSetup();
			// feed this interceptor to wirebox with virtual inheritance just in case, use registerNewInstance so its thread safe
			wirebox.registerNewInstance( 
					name         = "interceptor-" & arguments.interceptorName, 
					instancePath = arguments.interceptorClass 
				)
				.setScope( wirebox.getBinder().SCOPES.SINGLETON )
				.setThreadSafe( true )
				.setVirtualInheritance( "coldbox.system.Interceptor" )
				.addDIConstructorArgument( name="controller", value=controller )
				.addDIConstructorArgument( name="properties", value=arguments.interceptorProperties );
		}
		// retrieve, build and wire from wirebox
		var oInterceptor = wirebox.getInstance( "interceptor-" & arguments.interceptorName );
		
		// check for virtual $super, if it does, pass new properties
		if( structKeyExists( oInterceptor, "$super" ) ){
			oInterceptor.$super.setProperties( arguments.interceptorProperties );
		}

		return oInterceptor;
	}

	/**
	 * Retrieve an interceptor from the system by name, if not found, this method will throw an exception
	 * @interceptorName The name to retrieve
	 */
	function getInterceptor( required interceptorName ){
		var interceptorKey 	= arguments.interceptorName;
		var states 			= variables.interceptionStates;

		for( var key in states ){
			var state = states[ key ];
			if( state.exists( interceptorKey ) ){ 
				return state.getInterceptor( interceptorKey ); 
			}
		}

		// Throw Exception
		throw( 
			message = "Interceptor: #arguments.interceptorName# not found in any state: #structKeyList( states )#.",
			type    = "InterceptorService.InterceptorNotFound"
		);
	}

	/**
	 * Append a list of custom interception points to the CORE interception points and returns itself
	 *
	 * @customPoints A comma delimmited list or array of custom interception points to append. If they already exists, then they will not be added again.
	 * 
	 * @return  The current interception points
	 */
	array function appendInterceptionPoints( required customPoints ){

		// Inflate custom points
		if( isSimpleValue( arguments.customPoints ) ){
			arguments.customPoints = listToArray( arguments.customPoints );
		}

		for( var thisPoint in arguments.customPoints ){
			if( !arrayFindNoCase( variables.interceptionPoints, thisPoint ) ){
				variables.interceptionPoints.append( thisPoint );
			}
		}

		return variables.interceptionPoints;
	}

	/**
	 * Get a State Container, it will return a blank structure if the state is not found.
	 * 
	 * @state The state to retrieve
	 */
	function getStateContainer( required state ){

		if( structKeyExists( variables.interceptionStates, arguments.state ) ){
			return variables.interceptionStates[ arguments.state ];
		}

		return {};
	}

	/**
	 * Unregister an interceptor from an interception state or all states. If the state does not exists, it returns false
	 * @interceptorName The interceptor to unregister
	 * @state The state to unregister from, if not, passed, then from all states
	 */
	boolean function unregister( required interceptorName, state="" ){
		var unregistered = false;

		// Else, unregister from all states
		for( var thisState in variables.interceptionStates ){
			if( !len( arguments.state ) OR arguments.state eq thisState ){
				structFind( variables.interceptionStates, thisState )
					.unregister( arguments.interceptorName );
				unregistered = true;
			}

		}

		return unregistered;
	}

	/**
	 * Register an Interception point into a new or created interception state
	 *
	 * @interceptorKey The interceptor key to use for lookups in the state
	 * @state The state to create
	 * @oInterceptor The interceptor to register
	 * @interceptorMD The metadata about the interception point: {async, asyncPriority, eventPattern}
	 */
	function registerInterceptionPoint(
		required interceptorKey,
		required state,
		required oInterceptor,
		interceptorMD
	){
		var oInterceptorState = "";
		
		// Init md if not passed
		if( not structKeyExists( arguments, "interceptorMD") ){
			arguments.interceptorMD = newPointRecord();
		}

		// Verify if state doesn't exist, create it
		if ( NOT structKeyExists( variables.interceptionStates, arguments.state ) ){
			oInterceptorState = new coldbox.system.web.context.InterceptorState( 
				state 		= arguments.state, 
				logbox 		= controller.getLogBox(), 
				controller 	= controller 
			);
			variables.interceptionStates[ arguments.state ] = oInterceptorState;
		} else {
			// Get the State we need to register in
			oInterceptorState = variables.interceptionStates[  arguments.state ];
		}

		// Verify if the interceptor is already in the state
		if( NOT oInterceptorState.exists( arguments.interceptorKey ) ){
			//Register it
			oInterceptorState.register(
				interceptorKey 	= arguments.interceptorKey,
				interceptor 	= arguments.oInterceptor,
				interceptorMD 	= arguments.interceptorMD
			);
		}

		return this;
	}

	/****************************** PRIVATE *********************************/

	/**
	 * Create a new interception point record
	 */
	private struct function newPointRecord(){
		return { async = false, asyncPriority = "normal", eventPattern = "" };
	}

	/**
	 * Verifies the setup for interceptor classes is online
	 */
	private InterceptorService function wireboxSetup(){
		var wirebox = controller.getWireBox();
		
		// Check if handler mapped?
		if( NOT wirebox.getBinder().mappingExists( variables.INTERCEPTOR_BASE_CLASS ) ){
			// feed the base class
			wirebox.registerNewInstance(
					name         = variables.INTERCEPTOR_BASE_CLASS, 
					instancePath = variables.INTERCEPTOR_BASE_CLASS
				)
				.addDIConstructorArgument( name="controller", value=controller )
				.addDIConstructorArgument( name="properties", value={} )
				.setAutowire( false );
		}

		return this;
	}

	/**
	 * I get a components valid interception points
	 */
	private struct function parseMetadata( required metadata, required points ){
		var x 			= 1;
		var pointsFound = arguments.points;
		var currentList = arrayToList( variables.interceptionPoints );

		// Register local functions only
		if( structKeyExists( arguments.metadata, "functions" ) ){
			var fncLen = ArrayLen( arguments.metadata.functions );
			for( var x=1; x lte fncLen; x++ ){

				// Verify the @interceptionPoint annotation so the function can be registered as an interception point
				if( structKeyExists( arguments.metadata.functions[ x ], "interceptionPoint" ) ){
					// Register the point by convention and annotation
					currentList = arrayToList( appendInterceptionPoints( arguments.metadata.functions[ x ].name ) );
				}

				// verify its an interception point by comparing it to the local defined interception points
				// Also verify it has not been found already
				if ( listFindNoCase( currentList, arguments.metadata.functions[ x ].name ) AND
					 NOT structKeyExists( pointsFound, arguments.metadata.functions[ x ].name ) ){
					// Create point record
					var pointRecord = newPointRecord();
					
					// Discover point information
					if( structKeyExists( arguments.metadata.functions[ x ], "async" ) ){ 
						pointRecord.async = true; 
					}
					if( structKeyExists( arguments.metadata.functions[ x ], "asyncPriority" ) ){ 
						pointRecord.asyncPriority = arguments.metadata.functions[ x ].asyncPriority; 
					}
					if( structKeyExists( arguments.metadata.functions[ x ], "eventPattern" ) ){ 
						pointRecord.eventPattern = arguments.metadata.functions[ x ].eventPattern; 
					}
					
					// Insert to metadata struct of points found
					structInsert( pointsFound, arguments.metadata.functions[ x ].name, pointRecord );
				}

			}// loop over functions
		}

		// Start Registering inheritances
		if( 
			structKeyExists( arguments.metadata, "extends" ) 
			&&
			( arguments.metadata.extends.name neq "coldbox.system.Interceptor" 
				&&
			 arguments.metadata.extends.name neq "coldbox.system.EventHandler" )
		){
			// Recursive lookup
			parseMetadata( arguments.metadata.extends, pointsFound );
		}

		//return the interception points found
		return pointsFound;
	}

}