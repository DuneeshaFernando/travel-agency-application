import ballerina/io;
import ballerina/http;
import ballerina/log;
import ballerina/mysql;

string dbUser = "root";
string dbPassword = "test@123";

mysql:Client mysqlClient = check new (host= "192.168.1.6", port= 3306, user = dbUser, password = dbPassword, database = "airline");

function readOperation(mysql:Client mysqlClient, map<json> input) returns int{
    stream<record{}, error> resultStream =
        mysqlClient->query("Select count(*) as Total from reservations where first_name='" +
            input.FirstName.toString() +
            "' and last_name='" +
            input.LastName.toString() +
            "'");
    record {|record {} value;|}|error? result = resultStream.next();
    error? e = resultStream.close();
    if (result is record {|record {} value;|}) {
        if result.value["Total"]==1{
            return 1;
        }else{
            return 0;
        }
    } else if (result is error) {
        io:println("Next operation on the stream failed!", result);
        return 0;
    } else {
        io:println("Query result is empty");
        return 0;
    }
}

// Airline mocking service to check airline related details of a tour for a user
@http:ServiceConfig {basePath:"/reserve"}
service reserveItems on new http:Listener(7278) {
    // Resource to arrange airline related details of a tour
    @http:ResourceConfig {methods:["POST"], consumes:["application/json"],
        produces:["application/json"]}
    resource function airline (http:Caller caller, http:Request inRequest) returns error? {
        log:printInfo("reserving airline...");
        http:Response outResponse = new;
        map<json> inReqPayload = {};

        // JSON payload format for an HTTP out request.
        map<json> outReqPayload = {"FirstName": "", "LastName": "", "Preference": ""};
        // Try parsing the JSON payload from the user request
        var payload = inRequest.getJsonPayload();
        if (payload is map<json>) {
            // Valid JSON payload
            inReqPayload = payload;
        } else {
            // NOT a valid JSON payload
            outResponse.statusCode = 400;
            outResponse.setJsonPayload({"Message": "Invalid payload - Not a valid JSON payload"});
            var result = caller->respond(outResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }
            return;
        }
        
        outReqPayload["FirstName"] = inReqPayload["Name"];
        json | error airlinePreference = inReqPayload.Preference;
        
        // If payload parsing fails, send a "Bad Request" message as the response
        if (outReqPayload.FirstName is () || airlinePreference is error) {
            outResponse.statusCode = 400;
            outResponse.setJsonPayload({"Message": "Bad Request - Invalid Payload"});
            var result = caller->respond(outResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }            
            return;
        }
        
        // Reserve airline ticket for the user by calling Airline reservation service
        // construct the payload
        map<json> outReqPayloadAirline = outReqPayload.clone();
        string name = outReqPayload["FirstName"].toString();
        int|() index = name.indexOf(" ");
        int last = name.length();
        if (index is ()) {
            outReqPayloadAirline["FirstName"] = name.toJsonString();
            outReqPayloadAirline["LastName"] = " ";
        } else {
            outReqPayloadAirline["FirstName"] = name.substring(0, index).toJsonString();
            outReqPayloadAirline["LastName"] = name.substring(index+1, last).toJsonString();
        }
        outReqPayloadAirline["Preference"] = <json>airlinePreference;
        
        // Get the reservation status
        http:Response inResAirline = new;
        map<json> inRqstPayload = {};
        inRqstPayload = <@untainted>outReqPayloadAirline;
        int readAck = readOperation(mysqlClient, <@untainted>  inRqstPayload);
        if (readAck == 1) {
            io:println("Queried from the database successfully!");
            inResAirline.statusCode = 200;
            inResAirline.setJsonPayload({"Status": "Success"});
        } else {
            io:println("Data querying failed!");
            inResAirline.statusCode = 500;
            inResAirline.setJsonPayload({"Status": "Failed"});
        }

        var airlineResPayload = check <@untainted>inResAirline.getJsonPayload();
        string airlineStatus = airlineResPayload.Status.toString();
        // If reservation status is negative, send a failure response to user
        if (airlineStatus != "Success") {
            outResponse.statusCode = 500;
            outResponse.setJsonPayload({
                "Message": "Failed to reserve airline! " +
                "Provide a valid 'Preference' for 'Airline' and try again"
            });
            var result = caller->respond(outResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }
        }else{
            outResponse.statusCode = 200;
            outResponse.setJsonPayload({
                "Message": "Success"
            });
            var result = caller->respond(outResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }
        }
        return;
    }
}