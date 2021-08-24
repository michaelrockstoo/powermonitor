/*
 * IMPORTS
 *
 */
// Load up the Rocky web API management
#require "Rocky.agent.lib.nut:3.0.0"

// Load up the Twilio library
#require "Twilio.class.nut:1.0"

/*
 * CONSTANTS: WEB UI HTML
 *
 */
const HTML_STRING = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <title>Power Metering Station</title>
    <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css'>
    <link href='https://fonts.googleapis.com/css?family=Abel|Audiowide' rel='stylesheet'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <meta charset='UTF-8'>
    <style>
        .col-5 {-ms-flex:0 0 25%%;flex:0 0 25%%;max-width:25%%}
        .col-3 {-ms-flex:0 0 15%%;flex:0 0 15%%;max-width:15%%}
        .col-6 {-ms-flex:0 0 70%%;flex:0 0 70%%;max-width:70%%}
        .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
        body { background-color: #6C747E; }
        p {color: white; font-family: Abel, sans-serif; font-size: 18px;}
        p.box {margin-top: 2px; margin-bottom: 2px;}
        p.subhead {color:#ffcc00; font-size: 22px; line-height: 24px; vertical-align: middle;}
        p.postsubhead {margin-top: 15px;}
        p.colophon {font-size: 14px; text-align: center;}
        p.little {font-size: 14px; line-height: 16px; margin-top: 10px;}
        h2 {color: #ffcc00; font-family: Audiowide, sans-serif; font-weight:bold; font-size: 36px; margin-top: 10px;}
        h4 {color: white; font-family: Abel, sans-serif; font-weight:bold; font-size: 30px; margin-bottom: 10px;}
        td {color: white; font-family: Abel, sans-serif;}
        hr {border-color: #ffcc00;}
        .uicontent {border: 2px solid #ffcc00;}
        .container {padding: 20px;}
        .btn-warning {width: 200px;}
        .showhidewlans {-webkit-touch-callout: none; -webkit-user-select: none; -khtml-user-select: none;
                        -moz-user-select: none; -ms-user-select: none; user-select: none; cursor: pointer;
                        margin-bottom:0px; vertical-align: middle;}
        .modal {display: none; position: fixed; z-index: 1; left: 0; top: 0; width: 100%%; height: 100%%; overflow: auto;
                background-color: rgba(0,0,0,0.4)}
    .modal-content-ok {background-color: #37ACD1; margin: 10%% auto; padding: 5px;
                       border: 2px solid #2C8BA9; width: 80%%}
        .switch {position: relative;  display: inline-block;  width: 60px;  height: 28px;}
        .switch input {  opacity: 0;  width: 0;  height: 0;}
        .slider { position: absolute;  cursor: pointer;  top: 0;  left: 0;  right: 0;  bottom: 0;  background-color: #ccc;  -webkit-transition: .4s;  transition: .4s;}
        .slider:before { position: absolute;  content: '';  height: 20px;  width: 26px;  left: 4px;  bottom: 4px;  background-color: white;  -webkit-transition: .4s;  transition: .4s;}
        input:checked + .slider { background-color: #2196F3;}
        input:focus + .slider { box-shadow: 0 0 1px #2196F3;}
        input:checked + .slider:before {-webkit-transform: translateX(26px);  -ms-transform: translateX(26px);  transform: translateX(26px);}
        .slider.round { border-radius: 34px;}
        .slider.round:before { border-radius: 10px;}
        @media only screen and (max-width: 640px) {
            .container {padding: 5px;}
            .uicontent {border: 0px;}
            .col-1 {max-width: 0%%; flex: 0 0 0%%;}
            .col-3 {max-width: 0%%; flex: 0 0 0%%;}
            .col-5 {max-width: 25%%; flex: 0 0 25%%;}
            .col-6 {max-width: 100%%; flex: 0 0 100%%;}
            .btn-warning {width: 140px;}
        }
        
     </style>
</head>
<body>
   <div id='notify' class='modal'>
       <div class='modal-content-ok'>
           <h3 align='center' style='color: white; font-family: Abel'>Device&nbsp;state&nbsp;changed</h3>
       </div>
   </div>
    <div class='container'>
        <div class='row uicontent' align='center'>
            <div class='col'>
                <!-- Title and Data Readout Row -->
                <div class='row' align='center'>
                    <div class='col-3'></div>
                    <div class='col-6'>
                        <h2 class='text-center'>Power Monitor</h2>
                        <h4 id='status' class='text-center'>Device is <span>disconnected</span></h4>
                        <hr />
                            <div class='row' align='center'>
                            <div class='col-5'>
                                <p class='box' align='right'><b>Location</b></p>
                                <p class='box' align='right'><b>STPM32</b></p>
                            </div>
                            <div class='col-5'>
                                <p class='box' align='left' id='sl'><span>Unknown</span></p>
                                <p class='box' align='left' id='stpm'><span>Unknown</span></p>
                            </div>
                                <div class='col-5'>
                                <p class='box' align='right'><b>WAN IP</b></p>
                                <p class='box' align='right'><b>HTS221</b></p>
                           </div>
                            <div class='col-5'>
                                <p class='box' align='left' id='wip'><span>Unknown</span></p>
                                <p class='box' align='left' id='hts'><span>Unknown</span></p>
                           </div>
                            </div>
                        <hr />
                        <div class='row' align='center'>
                            <div class='col-5'>
                                <p class='box' align='right'><b>Temprature</b></p>
                                <p class='box' align='right'><b>Voltage</b></p>
                                <p class='box' align='right'><b>Power</b></p>
                            </div>
                            <div class='col-5'>
                                <p class='box' align='left' id='te'><span>Unknown</span>&nbsp;&deg;C&nbsp;</p>
                                <p class='box' align='left' id='vo'><span>Unknown</span>&nbsp;V&nbsp;</p>
                                <p class='box' align='left' id='po'><span>Unknown</span>&nbsp;W&nbsp;</p>
                            </div>
                            <div class='col-5'>
                                <p class='box' align='right'><b>Humidity</b></p>
                                <p class='box' align='right'><b>Current</b></p>
                                <p class='box' align='right'><b>Phi</b></p>
                            </div>
                            <div class='col-5'>
                                <p class='box' align='left' id='hu'><span>Unknown</span>&nbsp;&#37&nbsp;</p>
                                <p class='box' align='left' id='cu'><span>Unknown</span>&nbsp;mA&nbsp;</p align='left'>
                                <p class='box' align='left' id='pf'><span>Unknown</span>&nbsp;&nbsp;</p>
                            </div>
                        </div>
                    </div>
                    <div class='col-3'></div>
                </div>
                <!-- Graphic Readout -->
                <div class='row' align='center'>
                    <div class='col-3'></div>
                    <div class='col-6'>
                        <h4 class='showhidewlans text-center'>Graphic Charts</h4>
                        <div id='chartContainer' style='height: 240px; max-width: 920px; margin: 10px auto;'></div>
                        <div id='chartContainer2' style='height: 240px; max-width: 920px; margin: 10px auto;'></div>
                        </div>
                    <div class='col-3'></div>
                </div>
                <p>&nbsp;</p>
            </div>
        </div>
    </div>

    <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js'></script>
    <script src='https://canvasjs.com/assets/script/canvasjs.min.js'></script>
    <script>
        window.onload = function() {
    
        var tempraturedataPoints = [];
        var humiditydataPoints = [];
        
        var voltagedataPoints = [];
        var currentdataPoints = [];
        var powerdataPoints = [];
        
        var xValue = 0;
        var yValue1 = 3000;
        var yValue2 = 6000;
        
        var chart = new CanvasJS.Chart('chartContainer', {
            zoomEnabled: true,
        	theme: 'light2',
        	title: {
        		text: 'Temprature and humidity'
        	},
        	axisX: {
		        title: 'chart updates every 5 secs'
        	},	
        	legend: {
        		cursor:'pointer',
        		verticalAlign: 'top',
        		fontSize: 16,
        		fontColor: 'dimGrey',
        		itemclick : toggleDataSeries
             	},
        	data: [{
        		type: 'line',
        		name: 'Temprature',
        		showInLegend: true,
        		dataPoints: tempraturedataPoints
        	    },
        	    {
        	    type: 'line',
        		name: 'Humidity',
        		showInLegend: true,
        		dataPoints: humiditydataPoints
        	    },
        	]
        });
        var chart2 = new CanvasJS.Chart('chartContainer2', {
            zoomEnabled: true,
        	theme: 'light2',
        	title: {
        		text: 'Voltage and Current'
        	},
        	axisX: {
		        title: 'chart updates every 5 secs'
        	},	
        	legend: {
        		cursor:'pointer',
        		verticalAlign: 'top',
        		fontSize: 16,
        		fontColor: 'dimGrey',
        		itemclick : toggleDataSeries
             	},
        	data: [{
        		type: 'line',
        		name: 'Voltage',
        		showInLegend: true,
        		dataPoints: voltagedataPoints
        	    },
        	    {
        	    type: 'line',
        		name: 'Current',
        		showInLegend: true,
        		dataPoints: currentdataPoints
        	    },
        	]
        });
        readState();
        var dataTimer = setInterval(readState, 5000);
        function addData(data) {
       		//dataPoints.shift();
    		console.log(xValue);
    		tempraturedataPoints.push({x: xValue, y:  parseInt(data.te )});
    		humiditydataPoints.push({x: xValue, y:  parseInt(data.hu )});
    		
    		voltagedataPoints.push({x: xValue, y:  parseInt(data.vo )});
    		currentdataPoints.push({x: xValue, y:  parseInt(data.cu )});
    		
    		xValue++;
    		yValue1 = parseInt(data.te*1.20);
    		yValue2 = parseInt(data.hu*1.20);
            chart.options.data[0].legendText = ' Temparature ' + data.te + 'C';
	        chart.options.data[1].legendText = 'Humidity ' + data.hu + '%%'; 
     	    
     	    chart.render();
     	    chart2.render();
        }
        
        function readState() {
            $.ajax({
                url: agenturl + '/current',
                type: 'GET',
                cache: false,
                success: function(response) {
                    getState(addData);
                }
            });
        }   
        
        function toggleDataSeries(e) {
        	if (typeof(e.dataSeries.visible) === 'undefined' || e.dataSeries.visible) {
        		e.dataSeries.visible = false;
        	}
        	else {
        		e.dataSeries.visible = true;
        	}
        	chart.render();
        }
    }
    </script>
    <script>
    // Variables
    var agenturl = '%s';
    var state = 0;
    var timer;

    // Get initial readings
    getState(updateReadout);

    // Begin the online status update loop
    var stateTimer = setInterval(checkState, 5000);

    // Functions
    function updateReadout(data) {
        $('#status span').text(data.state);
        $('#wip span').text(data.wip);
        $('#te span').text(data.te);
        $('#hu span').text(data.hu);
        $('#vo span').text(data.vo);
        $('#cu span').text(data.cu);
        $('#po span').text(data.po);
        $('#pf span').text(data.pf);
        $('#sl span').text(data.sl);
        if(!data.stpm)
            $('#stpm span').text('Not Connected');
        else
            $('#stpm span').text('Connected');
        if(!data.hts)
            $('#hts span').text('Not Connected');
        else
            $('#hts span').text('Connected');

        let newstate = (data.state == 'connected' ? 1 : 2);

        // NOTE check for 'state != 0' stops modal appearing on launch
        if (state !=0 && newstate != state) {
            state = newstate;
            setModal();
        }
    }

    function getState(callback) {
        // Request the current data
        $.ajax({
            url : agenturl + '/current',
            type: 'GET',
            cache: false,
            success : function(response) {
                response = JSON.parse(response);
                if (callback) {
                    callback(response);
                }
            }
        });
    }

    function checkState() {
        // Request the current settings to extract the device's online state
        // NOTE This is called periodically via a timer (stateTimer)
        $.ajax({
            url: agenturl + '/current',
            type: 'GET',
            cache: false,
            success: function(response) {
                getState(updateReadout);
            }
        });
    }   
    

    function setModal() {
        clearTimeout(timer);

        var modal = document.getElementById('notify');
        modal.style.display = 'block';

        timer = setTimeout(function() {
            modal.style.display = 'none';
        }, 6000);

        window.onclick = function(event) {
            if (event.target == modal) {
                clearTimeout(timer);
                modal.style.display = 'none';
            }
        };
    }

    </script>
</body>
</html>";

/* 
 * GLOBALS
 *
 */
local webAPI = null;
local wifiData = null;
local wlanData = null;
local wlanIP = null;
local savedContext = null;
local isConnected = false;
local twilioClient = null;
local targetNumber = null;
local meters = null;
local stpmConnected = false;

/*
 * FUNCTIONS
 *
 */
function debugAPI(context, next) {
    // Display a UI API activity report - this is useful for agent-served UI debugging
    //server.log("API received a request at " + time() + ": " + context.req.method.toupper() + " @ " + context.req.path.tolower());
    if (context.req.rawbody.len() > 0) server.log("Request body: " + context.req.rawbody.tolower());

    // Invoke the next middleware (if any) registered with Rocky
    next();
}

function checkSecure(context) {
    // Verify that the request sent to the agent from a remote source was
    // made using HTTPS (ie. do not support HTTP)
    if (context.req.headers["x-forwarded-proto"] != "https") return false;
    return true;
}

function watchdog() {
    // Record the device state as recorded by the agent
    local state = device.isconnected();

    if (state != isConnected) {
        // The device state has changed, so send an SMS
        isConnected = state;
    }

    imp.wakeup(5, watchdog);
}


/*
 * Set handlers for messages sent by the device to the agent
 */
device.on("send.net.status", function(info) {
    // The device has sent its WLAN status data, so record ti
    wlanData = info;
});

device.on("send.adc.status", function(info) {
    // The device has sent its WLAN status data, so record ti
    meters = info;
});

/*
 * Set up the API that the agent will serve to drive the web UI
 */
webAPI = Rocky.init();

// Register the debug readout middleware
webAPI.use(debugAPI);

// Add a handler for GET requests made to /
// This will return the web UI HTML
webAPI.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// Add a handler for GET requests made to /current
// This will return status JSON to the web UI.
// NOTE The UI asks for this every 20 seconds
webAPI.get("/current", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    local sendData = {};
    isConnected = device.isconnected();
    sendData.state <- isConnected ? "connected" : "disconnected";
    if(isConnected){
        // If we have WLAN status data (we may not yet) send that too
        if (wlanData != null) {
            // Add the primary router's WAN IP to the stored info
            wlanData.wip <- context.getHeader("X-Forwarded-For");
    
            // Add the WLAN data to the requested-data payload
            sendData.ip <- wlanData.address;
            sendData.wip <- wlanData.wip;
            if(meters != null)
            {
                sendData.te <- meters.te;
                sendData.hu <- meters.hu;
                sendData.vo <- meters.vo;
                sendData.cu <- meters.cu;
                sendData.po <- meters.po;
                sendData.pf <- meters.pf;
                sendData.sl <- "Pittsburgh, PA";
                //sendData.tr <- meters.tr;
                sendData.gr <- meters.gr;
                sendData.re <- meters.re;
                sendData.stpm <- meters.stpm;
                sendData.hts <- meters.hts;
            }
        }
    }else{
                sendData.ip <- "Unknown";
                sendData.wip <- "Unknown";
                sendData.te <- "Unknown";
                sendData.hu <- "Unknown";
                sendData.vo <- "Unknown";
                sendData.cu <- "Unknown";
                sendData.po <- "Unknown";
                sendData.pf <- "Unknown";
                sendData.sl <- "Unknown";
                sendData.tr <- "Unknown";
                sendData.gr <- 0;
                sendData.re <- 0;
    }

    // Return the status information to the web UI
    //server.log(http.jsonencode(sendData));
    context.send(200, http.jsonencode(sendData));
});

// Add a handler for GET requests made to /list
// The web UI has requested a list of WLANs that the device can detect
webAPI.get("/list", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    // Ask the device for a list of WLANs and preserve the Rocky context object
    // for use when the data comes back from the device.
    // NOTE We don't do it here, but it is good practice to set a timer that will
    //      respond to the web UI request if the device does not return the list
    //      (it may be disconnnected)
    device.send("get.wlan.list", true);
    savedContext = context;
});

/*
 * Start the SMS alert watchdog
 */
watchdog();
