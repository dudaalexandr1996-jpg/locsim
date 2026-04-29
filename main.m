// Copyright (c) 2021 udevs
//
// // // //
// // // // //
// // This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.
This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
#import <stdio.h>
#import <getopt.h>
#import <libgen.h>
#import <string.h>
#import <stdlib.h>
#import <spawn.h>
#import "macros.h"
#import <CoreLocation/CoreLocation.h>
#import "LSMGPXParserDelegate.h"
#import "PrivateHeaders.h"
#define HELP_OPT 900
#define PLIST_OPT 500
#define EXPORT_PLIST_OPT 501
#define EXPORT_PLIST_ONLY_OPT 502
#define SPEED_ACCURACY_OPT 503
#define COURSE_ACCURACY_OPT 504
#define TEMP_DIR @"/tmp/"
static void post_required_timezone_update(){
//try our best to update time zone instantly, though it totally depends on whether xp
CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCe
}
static void start_loc_sim(CLLocation *loc, int delivery, int repeat){
CLSimulationManager *simManager = [[CLSimulationManager alloc] init];
if (delivery >= 0) simManager.locationDeliveryBehavior = (uint8_t)delivery;
if (repeat >= 0) simManager.locationRepeatBehavior = (uint8_t)repeat;
[simManager stopLocationSimulation];
[simManager clearSimulatedLocations];
[simManager appendSimulatedLocation:loc];
[simManager flush];
[simManager startLocationSimulation];
post_required_timezone_update();
}
static void start_scenario_sim(NSString *path, int delivery, int repeat){
CLSimulationManager *simManager = [[CLSimulationManager alloc] init];
if (delivery >= 0) simManager.locationDeliveryBehavior = (uint8_t)delivery;
if (repeat >= 0) simManager.locationRepeatBehavior = (uint8_t)repeat;
[simManager stopLocationSimulation];
[simManager clearSimulatedLocations];
[simManager loadScenarioFromURL:[NSURL fileURLWithPath:path]];
[simManager flush];
[simManager startLocationSimulation];
post_required_timezone_update();
}
static void stop_loc_sim(){
CLSimulationManager *simManager = [[CLSimulationManager alloc] init];
[simManager stopLocationSimulation];
[simManager clearSimulatedLocations];
[simManager flush];
post_required_timezone_update();
}
static NSArray <NSArray *>* world_capital_coor_arr(){
return WORLD_CAPITAL_COOR_ARRAY;
}
static CLLocationCoordinate2D rand_world_capital_coor(){
NSArray *coords = world_capital_coor_arr();
srand(time(NULL));
int rdi = rand() % coords.count;
NSArray *coor = coords[rdi];
return CLLocationCoordinate2DMake([coor.firstObject doubleValue], [coor.lastObject do
}
static void print_help(){
PRINT("Usage: locsim <SUBCOMMAND> [LATITUDE] [LONGITUDE] [OPTIONS]\n"
"if LATITUDE and LONGITUDE not specified, random values will be generated\n
"SUBCOMMAND:\n"
" start start location simulation\n"
" stop stop location simulation\n"
"OPTIONS:\n"
" -x, --latitude <double>: latitude of geographical coordinate\n"
" -y, --longitude <double>: longitude of geographical coordinate\n"
" -a, --altitude <double>: location altitude\n"
" -h, --haccuracy <double>: radius of uncertainty for the geographical
" -v, --vaccuracy <double>: accuracy of the altitude value, measured in
" -s, --speed <double>: speed, or override average speed if -g specifie
" --saccuracy <double>: accuracy of the speed value, measured in m/
" -c, --course <double>: direction values measured in degrees\n"
" --caccuracy <double>: accuracy of the course value, measured in d
" -t, --time <double>: epoch time to associate with the location\n"
" -f, --force: force stop simulation, requires root access\n"
" -d, --delivery <int>: location delivery behaviour\n"
" 0 = pass through\n"
" 1 = consider other factors\n"
" -r, --repeat <int>: location repeat behaviour\n"
" 0 = unavailable\n"
" 1 = last location/entry\n"
" 2 = loop (valid if -g, --gpx specified)\n"
" --help: show this help\n"
"ADDITIONAL GPX OPTIONS:\n"
" -g, --gpx <file>: gpx file path\n"
" --plist <file>: exported or valid plist file path\n"
" -l, --lifespan <double>: location lifespan, send unavailable once exp
" -p, --type <int>: type\n"
" --export-plist <file>: export converted gpx file to plist\n"
" --export-only: export converted gpx file to plist without running sim
);
exit(-1);
}
int main(int argc, char *argv[], char *envp[]) {
static struct option longopts[] = {
{ "latitude", required_argument, 0, 'x' },
{ "longitude", required_argument, 0, 'y' },
{ "altitude", required_argument, 0, 'a' },
{ "haccuracy", required_argument, 0, 'h' },
{ "vaccuracy", required_argument, 0, 'v' },
{ "time", required_argument, 0, 't' },
{ "force", required_argument, 0, 'f' },
{ "gpx", required_argument, 0, 'g' },
{ "speed", required_argument, 0, 's' },
{ "saccuracy", required_argument, 0, SPEED_ACCURACY_OPT },
{ "course", required_argument, 0, 'c' },
{ "caccuracy", required_argument, 0, COURSE_ACCURACY_OPT },
{ "lifespan", required_argument, 0, 'l' },
{ "type", required_argument, 0, 'p' },
{ "delivery", required_argument, 0, 'd' },
{ "repeat", required_argument, 0, 'r' },
{ "plist", required_argument, 0, PLIST_OPT },
{ "export-plist", required_argument, 0, EXPORT_PLIST_OPT },
{ "export-only", no_argument, 0, EXPORT_PLIST_ONLY_OPT },
{ "help", no_argument, 0, HELP_OPT},
{ 0, 0, 0, 0 }
};
CLLocationCoordinate2D coor = rand_world_capital_coor();
CLLocationDistance alt = 0.0;
CLLocationAccuracy ha = 0.0;
CLLocationAccuracy va = 0.0;
NSDate *ts = [NSDate date];
double s = -1.0;
double c = -1.0;
BOOL force = NO;
int ldb = -1;
int lrb = -1;
//gpx
NSString *gpx;
double l = -1.0;
double sa = -1.0;
double ca = -1.0;
int p = -1;
NSString *plist;
NSString *exportPlist;
BOOL exportOnly = NO;
int opt;
while ((opt = getopt_long(argc, argv, "x:y:a:h:v:t:fg:s:l:p:d:r:c:", longopts, switch (opt){
case 'x':
NULL))
case 'y':
case 'a':
case 'h':
coor.latitude = [@(optarg) doubleValue];
break;
coor.longitude = [@(optarg) doubleValue];
break;
alt = [@(optarg) doubleValue];
break;
ha = [@(optarg) doubleValue];
break;
case 'v':
va = [@(optarg) doubleValue];
break;
case 't':
ts = [NSDate dateWithTimeIntervalSince1970:[@(optarg) doubleV
break;
case 'f':
force = YES;
break;
case 'g':
gpx = @(optarg);
break;
case 's':
s = [@(optarg) doubleValue];
break;
case 'c':
c = [@(optarg) doubleValue];
break;
case 'l':
s = [@(optarg) doubleValue];
break;
case 'p':
p = [@(optarg) intValue];
break;
case 'd':
ldb = [@(optarg) intValue];
break;
case 'r':
lrb = [@(optarg) intValue];
break;
case EXPORT_PLIST_OPT:
exportPlist = @(optarg);
break;
case PLIST_OPT:
plist = @(optarg);
break;
case EXPORT_PLIST_ONLY_OPT:
exportOnly = YES;
break;
case SPEED_ACCURACY_OPT:
sa = [@(optarg) doubleValue];
if (@available(iOS 13.4, *)); else WARNING("WARNING: --saccur
break;
case COURSE_ACCURACY_OPT:
ca = [@(optarg) doubleValue];
if (@available(iOS 13.4, *)); else WARNING("WARNING: --caccur
break;
default:
print_help();
break;
}
}
argc -= optind;
argv += optind;
if (argc < 1) print_help();
if (argc > 2){
coor.latitude = [@(argv[1]) doubleValue];
coor.longitude = [@(argv[2]) doubleValue];
}
if (strcasecmp(argv[0], "start") == 0){
if (plist.length > 0){
if (access(strdup(plist.UTF8String), F_OK) != 0){
NSString *plistExt = [NSString stringWithFormat:@"%@.plist",
if (access(strdup(plistExt.UTF8String), F_OK) != 0){
ERROR("ERROR: \"%s\" does not exist!\n", plist.UTF8St
return 2;
}else{
WARNING("WARNING: \"%s\" does not exist, instead uses
plist = plistExt;
}
}
if (![plist.pathExtension isEqualToString:@"plist"]) {ERROR("ERROR: \
NSDictionary *options = [NSDictionary dictionaryWithContentsOfFile:pl
if (options){
ldb = [options[@"LocationDeliveryBehavior"] ?: @(ldb) intValu
lrb = [options[@"LocationRepeatBehavior"] ?: @(lrb) intValue]
}
start_scenario_sim(plist, ldb, lrb);
}else if (gpx.length > 0){
if (access(strdup(gpx.UTF8String), F_OK) != 0) {ERROR("ERROR: \"%s\"
NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:[
LSMGPXParserDelegate *gpxParserDelegate = [LSMGPXParserDelegate new];
gpxParserDelegate.averageSpeed = s > 0 ? s : gpxParserDelegate.averag
gpxParserDelegate.hAccuracy = ha > 0 ? ha : gpxParserDelegate.hAccura
gpxParserDelegate.vAccuracy = va > 0 ? va : gpxParserDelegate.vAccura
gpxParserDelegate.lifeSpan = l > 0 ? l : gpxParserDelegate.lifeSpan;
gpxParserDelegate.locationDeliveryBehavior = ldb >= 0 ? ldb : gpxPar
gpxParserDelegate.locationRepeatBehavior = lrb >= 0 ? lrb : gpxParse
[xmlParser setDelegate:gpxParserDelegate];
[xmlParser parse];
NSString *output = [NSString stringWithFormat:@"%@%ld.plist", TEMP_DI
if (exportPlist.length > 0){
if (access(strdup(dirname((char *)exportPlist.UTF8String)), W
if (![exportPlist.pathExtension isEqualToString:@"plist"]) ex
output = exportPlist;
}
[[gpxParserDelegate scenario] writeToFile:output atomically:NO];
if (exportPlist.length > 0) {PRINT("Exported to \"%s\"\n", output.UTF
if (!exportOnly) start_scenario_sim(output, ldb, lrb);
}else{
if (!CLLocationCoordinate2DIsValid(coor)) {ERROR("ERROR: Invalid coor
s = s > 0 ? s : 0.0;
CLLocation *loc;
if (@available(iOS 13.4, *)){
loc = [[CLLocation alloc] initWithCoordinate:coor altitude:al
}else{
loc = [[CLLocation alloc] initWithCoordinate:coor altitude:al
}
start_loc_sim(loc, ldb, lrb);
PRINT("latitude: %.15f\nlongitude: %.15f\naltitude: %.15f\nhorizontal
}
}else if (strcasecmp(argv[0], "stop") == 0){
if (force){
if (getuid() == 0){
pid_t pid;
int status;
const char *args[] = {"killall", "-9", "locationd", NULL};
posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char * con
waitpid(pid, &status, WEXITED);
}else{
WARNING("WARNING: -f, --force requires root access, flag igno
stop_loc_sim();
}
}else{
stop_loc_sim();
}
}else{
print_help();
}
return 0;
}
