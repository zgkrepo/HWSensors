//
//  HWMonitorExtra.m
//  HWSensors
//
//  Created by kozlek on 03/02/12.
//
//  Copyright (c) 2012 Natan Zalkin <natan.zalkin@me.com>. All rights reserved.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.



#import "NSString+TruncateToWidth.h"
#import "HWMonitorDefinitions.h"

#import "HWMonitorExtra.h"

#define GetLocalizedString(key) \
[[self bundle] localizedStringForKey:(key) value:@"" table:nil]

@implementation HWMonitorExtra

@synthesize engine = _engine;
@synthesize favorites = _favorites;

- (id)initWithBundle:(NSBundle *)bundle
{
    self = [super initWithBundle:bundle];
    
    if (self == nil) return nil;
    
    _defaults = [[BundleUserDefaults alloc] initWithPersistentDomainName:@"org.hwsensors.HWMonitor"];
    
    _showVolumeNames = [_defaults integerForKey:kHWMonitorShowVolumeNames];
    
    // Call undocumented function
    [[NSUserDefaultsController sharedUserDefaultsController] _setDefaults:_defaults];
    
    _prefsIcon = [[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"preferences" ofType:@"png"]];
    
    [self loadIconNamed:kHWMonitorIconDefault];
    [self loadIconNamed:kHWMonitorIconThermometer];
    [self loadIconNamed:kHWMonitorIconDevice];
    [self loadIconNamed:kHWMonitorIconTemperatures];
    [self loadIconNamed:kHWMonitorIconHddTemperatures];
    [self loadIconNamed:kHWMonitorIconSsdLife];
    [self loadIconNamed:kHWMonitorIconMultipliers];
    [self loadIconNamed:kHWMonitorIconFrequencies];
    [self loadIconNamed:kHWMonitorIconTachometers];
    [self loadIconNamed:kHWMonitorIconVoltages];
    
    HWMonitorView *view = [[HWMonitorView alloc] initWithFrame:[[self view] frame] menuExtra:self];
    
    HWMonitorIcon *icon = [self getIconByName:kHWMonitorIconThermometer];
    
    [view setImage:[icon image]];
    [view setAlternateImage:[icon alternateImage]];
    [view setUseShadowEffect:YES];
    
    [self setView:view];
    
    _mainMenu = [[NSMenu alloc] init];
    
    [_mainMenu setAutoenablesItems: NO];
    [_mainMenu setDelegate:(id<NSMenuDelegate>)[self view]];
    
    _menuFont = [NSFont boldSystemFontOfSize:10.0];
    [_mainMenu setFont:_menuFont];
    
    [self setMenu:_mainMenu];
    
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    
    [style setTabStops:[NSArray array]];
    [style addTabStop:[[NSTextTab alloc] initWithType:NSRightTabStopType location:[[NSAttributedString alloc] initWithString:@"0" attributes:[NSDictionary dictionaryWithObjectsAndKeys:_menuFont, NSFontAttributeName,nil]].size.width * (kHWMonitorMenuTitleWidth + kHWMonitorMenuValueWidth)]];
    
    _menuAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                       style, NSParagraphStyleAttributeName,
                       _menuFont, NSFontAttributeName,
                       nil];
    
    _subtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSFont boldSystemFontOfSize:9.0], NSFontAttributeName,
                           [NSColor disabledControlTextColor], NSForegroundColorAttributeName,
                           nil];
    
    _blackColorAttribute = [NSDictionary dictionaryWithObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    _orangeColorAttribute = [NSDictionary dictionaryWithObject:[NSColor orangeColor] forKey:NSForegroundColorAttributeName];
    _redColorAttribute = [NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
    
    [NSBundle loadNibNamed:@"PrefsMenu" owner:self];
    
    // Timer setup
    [self updateRateChanged:nil];
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(updateLoop)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(updateLoop)];
    
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:0.1 invocation:invocation repeats:YES] forMode:NSRunLoopCommonModes];
    
    // Register PM events
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self selector: @selector(systemWillSleep:) name: NSWorkspaceWillSleepNotification object: NULL];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self selector: @selector(systemDidWake:) name: NSWorkspaceDidWakeNotification object: NULL];
    
    // Register HWMonitorNotifications
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(favoritesChanged:) name: HWMonitorFavoritesChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(useFahrenheitChanged:) name: HWMonitorUseFahrenheitChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(useBigFontChanged:) name: HWMonitorUseBigFontChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(useShadowEffectChanged:) name: HWMonitorUseShadowsChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(showHiddenSensorsChanged:) name: HWMonitorShowHiddenChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(useBSDNamesChanged:) name: HWMonitorUseBSDNamesChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(showVolumeNamesChanged:) name: HWMonitorShowVolumeNamesChanged object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(itemsRequested:) name: HWMonitorRequestItems object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(appIsActiveChanged:) name: HWMonitorAppIsActive object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(updateRateChanged:) name: HWMonitorUpdateRateChanged object: NULL];
    
    [self performSelector:@selector(rebuildSensorsList) withObject:nil afterDelay:0.0];
    
    return self;
}

- (void)loadIconNamed:(NSString*)name
{
    if (!_icons)
        _icons = [[NSMutableDictionary alloc] init];
    
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:name ofType:@"png"]];
    
    [image setTemplate:YES];
    
    NSImage *altImage = [[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:[name stringByAppendingString:@"_template"] ofType:@"png"]];
    
    [altImage setTemplate:YES];
    
    [_icons setObject:[HWMonitorIcon iconWithName:name image:image alternateImage:altImage] forKey:name];
}

- (HWMonitorIcon*)getIconByName:(NSString*)name
{
    return [_icons objectForKey:name];
}

- (HWMonitorIcon*)getIconByGroup:(NSUInteger)group
{
    if ((group & kHWSensorGroupTemperature) || (group & kSMARTSensorGroupTemperature)) {
        return [self getIconByName:kHWMonitorIconTemperatures];
    }
    else if ((group & kSMARTSensorGroupRemainingLife) || (group & kSMARTSensorGroupRemainingBlocks)) {
        return [self getIconByName:kHWMonitorIconSsdLife];
    }
    else if (group & kHWSensorGroupFrequency) {
        return [self getIconByName:kHWMonitorIconFrequencies];
    }
    else if (group & kHWSensorGroupMultiplier) {
        return [self getIconByName:kHWMonitorIconMultipliers];
    }
    else if ((group & kHWSensorGroupPWM) || (group & kHWSensorGroupTachometer)) {
        return [self getIconByName:kHWMonitorIconTachometers];
    }
    else if (group & kHWSensorGroupVoltage) {
        return [self getIconByName:kHWMonitorIconVoltages];
    }
    
    return nil;
}

- (void)updateSmartSensors; 
{
    [_engine updateSmartSensors];
}

- (void)updateSmartSensorsThreaded
{
    [self performSelectorInBackground:@selector(updateSmartSensors) withObject:nil];
}

- (void)updateSmcSensors
{
    if ([self isMenuDown] || _monitoringAppIsActive)
        [_engine updateSmcSensors];
    else 
        [_engine updateFavoritesSensors:_favorites];
    
    if (_monitoringAppIsActive) {
            
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
        
        for (HWMonitorSensor *sensor in [_engine sensors]) {
            //if ([sensor valueHasBeenChanged])
            [values setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              [sensor rawValue],       kHWMonitorKeyRawValue,
                              [sensor formattedValue], kHWMonitorKeyValue,
                              nil] forKey:[sensor name]];
        }
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorValuesChanged object:nil userInfo:values deliverImmediately:YES];
    }
    
}

- (void)updateSmcSensorsThreaded
{
    [self performSelectorInBackground:@selector(updateSmcSensors) withObject:nil];
}

- (void)updateMenuTextForceAllSensors:(BOOL)allSensors
{
    [[self view] setNeedsDisplay:YES];
    
    if (!allSensors && ![self isMenuDown])
        return;
       
    for (HWMonitorSensor *sensor in [_engine sensors]) {
        if (([self isMenuDown] || allSensors) && [[sensor representedObject] isVisible] && [sensor valueHasBeenChanged]) {
            
            NSMutableAttributedString * title = [[NSMutableAttributedString alloc] init];
            
            NSDictionary *titleColor = nil;
            NSDictionary *valueColor = nil;
            
            NSString *value = [sensor formattedValue];
            
            switch ([sensor level]) {
                    /*case kHWSensorLevelDisabled:
                     break;
                     
                     case kHWSensorLevelNormal:
                     break;*/
                    
                case kHWSensorLevelModerate:
                    titleColor = _blackColorAttribute;
                    valueColor = _orangeColorAttribute;
                    break;
                    
                case kHWSensorLevelHigh:
                    titleColor = _blackColorAttribute;
                    valueColor = _redColorAttribute;
                    break;
                    
                case kHWSensorLevelExceeded:
                    titleColor = _redColorAttribute;
                    valueColor = _redColorAttribute;
                    break;
                    
                default:
                    titleColor = _blackColorAttribute;
                    valueColor = _blackColorAttribute;
                    break;
            }
            
            [title appendAttributedString:[[NSAttributedString alloc] initWithString:[[sensor representedObject] title] attributes:titleColor]];
            
            [title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t"]];
            [title appendAttributedString:[[NSAttributedString alloc] initWithString:value attributes:valueColor]];
            
            [title addAttributes:_menuAttributes range:NSMakeRange(0, [title length])];
            
            // Add subtitle
            if ([sensor disk] && _showVolumeNames)
                [title appendAttributedString:[[NSAttributedString alloc] initWithString:[[NSString stringWithFormat:@"\n %@", [[sensor disk] volumesNames]] stringByTruncatingToWidth:[[NSAttributedString alloc] initWithString:@"0" attributes:[NSDictionary dictionaryWithObject:_menuFont forKey:NSFontAttributeName]].size.width * (kHWMonitorMenuTitleWidth + kHWMonitorMenuValueWidth) withFont:_menuFont] attributes:_subtitleAttributes]];
            
            // Update menu item title
            [[[sensor representedObject] menuItem] setAttributedTitle:title];
        }
    }
}

- (void)updateMenuTextForced
{
    [self updateMenuTextForceAllSensors:YES];
}

- (void)updateMenuText
{
    [self updateMenuTextForceAllSensors:NO];
}

- (void)updateLoop
{
    BOOL menuNeedsUpdate = false;
    
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0.0];
    
    if ([_smcSensorsLastUpdated timeIntervalSinceNow] < (- _smcSensorsUpdateInterval)) {
        [self updateSmcSensorsThreaded];
        _smcSensorsLastUpdated = now;
        menuNeedsUpdate = true;
    }
    
    if ([_smartSensorsLastUpdated timeIntervalSinceNow] < (- _smartSensorsUpdateInterval)) {
        [self updateSmartSensorsThreaded];
        _smartSensorsLastUpdated = now;
        menuNeedsUpdate = true;
    }
    
    if (menuNeedsUpdate)
        [self updateMenuText];
}

- (void)openPreferences:(id)sender
{
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"org.hwsensors.HWMonitor" options:NSWorkspaceLaunchAsync additionalEventParamDescriptor:nil launchIdentifier:nil];
}

-(void)checkGroupsVisibilities
{
    BOOL hasVisibleGroupsBefore = NO;
    
    for (HWMonitorGroup *group in _groups) {
        [group setFirst:!hasVisibleGroupsBefore];
        hasVisibleGroupsBefore = hasVisibleGroupsBefore | [group checkVisibility];
    }
}

- (void)rebuildSensorsList
{
    if (!_engine) {
        _engine = [[HWMonitorEngine alloc] initWithBundle:[self bundle]];
        [(HWMonitorView*)[self view] setEngine:_engine];
    }
    
    if (!_favorites) {
        _favorites = [[NSMutableArray alloc] init];
        [(HWMonitorView*)[self view] setFavorites:_favorites];
    }
    
    if (!_groups)
        _groups = [[NSMutableArray alloc] init];
    else 
        [_groups removeAllObjects];
    
    [_mainMenu removeAllItems];
    
    [_engine setUseFahrenheit:[_defaults boolForKey:kHWMonitorUseFahrenheitKey]];
    [_engine setUseBSDNames:[_defaults boolForKey:kHWMonitorUseBSDNames]];
    
    [(HWMonitorView*)[self view] setUseBigFont:[_defaults boolForKey:kHWMonitorUseBigStatusMenuFont]];
    [(HWMonitorView*)[self view] setUseShadowEffect:[_defaults boolForKey:kHWMonitorUseShadowEffect]];
    
    [_engine rebuildSensorsList];
    
    if ([[_engine sensors] count] > 0) {
        
        [_favorites removeAllObjects];

        NSArray *favoritesList = [_defaults objectForKey:kHWMonitorFavoritesList];
        
        if (favoritesList) {
            
            NSUInteger i = 0;
            
            for (i = 0; i < [favoritesList count]; i++) {
                
                NSString *name = [favoritesList objectAtIndex:i];
                
                HWMonitorSensor *sensor = nil;
                HWMonitorIcon *icon = nil;
                
                if ((sensor = [[_engine keys] objectForKey:name])) {
                    [_favorites addObject:sensor];
                }
                else if ((icon = [_icons objectForKey:name])) {
                    [_favorites addObject:icon];
                }
            }
        }
        
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kHWSensorGroupTemperature menu:_mainMenu font:_menuFont title:GetLocalizedString(@"TEMPERATURES") image:[[self getIconByName:kHWMonitorIconTemperatures] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kSMARTSensorGroupTemperature menu:_mainMenu font:_menuFont title:GetLocalizedString(@"DRIVE TEMPERATURES") image:[[self getIconByName:kHWMonitorIconHddTemperatures] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kSMARTSensorGroupRemainingLife menu:_mainMenu font:_menuFont title:GetLocalizedString(@"SSD REMAINING LIFE") image:[[self getIconByName:kHWMonitorIconSsdLife] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kSMARTSensorGroupRemainingBlocks menu:_mainMenu font:_menuFont title:GetLocalizedString(@"SSD REMAINING BLOCKS") image:[[self getIconByName:kHWMonitorIconSsdLife] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kHWSensorGroupMultiplier | kHWSensorGroupFrequency menu:_mainMenu font:_menuFont title:GetLocalizedString(@"FREQUENCIES") image:[[self getIconByName:kHWMonitorIconFrequencies] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kHWSensorGroupPWM |kHWSensorGroupTachometer menu:_mainMenu font:_menuFont title:GetLocalizedString(@"FANS") image:[[self getIconByName:kHWMonitorIconTachometers] image]]];
        [_groups addObject:[HWMonitorGroup groupWithEngine:_engine sensorGroup:kHWSensorGroupVoltage menu:_mainMenu font:_menuFont title:GetLocalizedString(@"VOLTAGES") image:[[self getIconByName:kHWMonitorIconVoltages] image]]];
        
        NSArray *hiddenList = [_defaults objectForKey:kHWMonitorHiddenList];
        
        for (NSString *key in hiddenList) {
            if ([[[_engine keys] allKeys] containsObject:key]) {
                
                HWMonitorSensor *sensor = [[_engine keys] objectForKey:key];
                
                if (sensor)
                    [[sensor representedObject] setVisible:NO];
            }
        }
        
        [self checkGroupsVisibilities];
            
        [_mainMenu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem * prefsItem = [[NSMenuItem alloc]initWithTitle:GetLocalizedString(@"Preferences...") action:@selector(openPreferences:) keyEquivalent:@""];
        
        NSImage *prefsImage = [[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"preferences" ofType:@"png"]];
        [prefsImage setTemplate:YES];
        
        [prefsItem setImage:prefsImage];
        [prefsItem setTarget:self];
        
        [_mainMenu addItem:prefsItem];
        
        [self updateMenuTextForced];
    }
    else {
        NSMenuItem * item = [[NSMenuItem alloc]initWithTitle:GetLocalizedString(@"No sensors found") action:nil keyEquivalent:@""];
        
        [item setEnabled:FALSE];
        
        [_mainMenu addItem:item];
    }
    
    [self itemsRequested:nil];
}

- (void)itemsRequested:(NSNotification*)aNotification
{
    NSMutableArray *favoritesList = [[NSMutableArray alloc] init];
    
    for (id object in _favorites)
        [favoritesList addObject:[object name]];
    
    NSMutableDictionary *sensorsList = [[NSMutableDictionary alloc] init];
    
    int index = 0;
    
    for (HWMonitorSensor *sensor in [_engine sensors]) {
        [sensorsList setValue:[NSDictionary dictionaryWithObjectsAndKeys:
                               [sensor name], kHWMonitorKeyName,
                               [sensor title], kHWMonitorKeyTitle,
                               [sensor rawValue], kHWMonitorKeyRawValue,
                               [sensor formattedValue], kHWMonitorKeyValue,
                               [NSNumber numberWithLong:[sensor group]], kHWMonitorKeyGroup,
                               [NSNumber numberWithBool:[_favorites containsObject:sensor]], kHWMonitorKeyFavorite,
                               [NSNumber numberWithBool:[[sensor representedObject] isVisible]], kHWMonitorKeyVisible,
                               [NSNumber numberWithInt:index], kHWMonitorKeyIndex,
                               nil] forKey:[sensor name]];
        
        index++;
    }
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorRecieveItems object:[favoritesList componentsJoinedByString:@","] userInfo:sensorsList deliverImmediately:YES];
}

- (void)appIsActiveChanged:(NSNotification*)aNotification
{
    _monitoringAppIsActive = aNotification && [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
}

- (void)favoritesChanged:(NSNotification*)aNotification
{    
    [_favorites removeAllObjects];
    
    NSArray *favoritesList = [(NSString*)[aNotification object] componentsSeparatedByString:@","];
    
    if (favoritesList) {
        
        NSUInteger i = 0;
        
        for (i = 0; i < [favoritesList count]; i++) {
            
            NSString *name = [favoritesList objectAtIndex:i];
            
            HWMonitorIcon *icon = [_icons objectForKey:name];
            
            if (icon) {
                [_favorites addObject:icon];
            }
            else {
                HWMonitorSensor *sensor = [[_engine keys] objectForKey:name];
                
                if (sensor)
                    [_favorites addObject:sensor];
            }
        }
    }
    
    [_defaults setObject:favoritesList forKey:kHWMonitorFavoritesList];
    
    NSMutableArray *hiddenList = [[NSMutableArray alloc] init];
    NSDictionary *info = [aNotification userInfo];
    
    for (NSString *key in [info allKeys]) {
        NSNumber *visible = [info valueForKey:key];
        HWMonitorSensor *sensor = [[_engine keys] valueForKey:key];
        
        if (visible && sensor) {
            [[sensor representedObject] setVisible:[visible boolValue]];
            
            if (![visible boolValue]) 
                [hiddenList addObject:[sensor name]];
        }
    }
    
    [self checkGroupsVisibilities];
    
    [_defaults setObject:hiddenList forKey:kHWMonitorHiddenList];
    
    [_defaults synchronize];
    
    [[self view] setNeedsDisplay:YES];
}

- (void)useFahrenheitChanged:(NSNotification*)aNotification
{
    BOOL useFahrenheit = [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
    
    [_engine setUseFahrenheit:useFahrenheit];
    [self updateMenuTextForced];
    [[self view] setNeedsDisplay:YES];
    
    [_defaults setBool:useFahrenheit forKey:kHWMonitorUseFahrenheitKey];
    [_defaults synchronize];
}

- (void)useBigFontChanged:(NSNotification*)aNotification
{   
    BOOL useBigFont = [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
    
    [(HWMonitorView*)[self view] setUseBigFont:useBigFont];
    [self updateMenuTextForced];
    [[self view] setNeedsDisplay:YES];
    
    [_defaults setBool:useBigFont forKey:kHWMonitorUseBigStatusMenuFont];
    [_defaults synchronize];
}

- (void)useShadowEffectChanged:(NSNotification*)aNotification
{
    BOOL useShadowEffect = [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
    
    [(HWMonitorView*)[self view] setUseShadowEffect:useShadowEffect];
    [self updateMenuTextForced];
    [[self view] setNeedsDisplay:YES];
    
    [_defaults setBool:useShadowEffect forKey:kHWMonitorUseShadowEffect];
    [_defaults synchronize];
}

- (void)useBSDNamesChanged:(NSNotification*)aNotification
{
    BOOL useBSDNames = [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
    
    [_defaults setInteger:useBSDNames forKey:kHWMonitorUseBSDNames];
    [_defaults synchronize];
    
    [_engine setUseBSDNames:useBSDNames];
    
    for (HWMonitorSensor *sensor in [_engine sensors])
        if ([sensor disk])
            [[sensor representedObject] setTitle:[sensor title]];
    
    [self updateMenuTextForced];
    
    [self itemsRequested:nil];
}

- (void)showVolumeNamesChanged:(NSNotification*)aNotification
{
    _showVolumeNames = [aNotification object] && [[aNotification object] isKindOfClass:[NSString class]] ? [(NSString*)[aNotification object] isEqualToString:HWMonitorBooleanYES] : NO;
    
    [_defaults setInteger:_showVolumeNames forKey:kHWMonitorShowVolumeNames];
    [_defaults synchronize];
    
    [self updateMenuTextForced];
}

-(void)updateRateChanged:(NSNotification *)aNotification
{
    if (aNotification)
        _smcSensorsUpdateInterval = [[[aNotification userInfo] valueForKey:kHWMonitorSmcSensorsUpdateRate] floatValue];
    else
        _smcSensorsUpdateInterval = [_defaults floatForKey:kHWMonitorSmcSensorsUpdateRate];
        
    _smcSensorsUpdateInterval = _smcSensorsUpdateInterval > 10 ? 10 : _smcSensorsUpdateInterval < 1 ? 1 : _smcSensorsUpdateInterval;
    _smcSensorsLastUpdated = [NSDate dateWithTimeIntervalSince1970:0.0];
    
    if (aNotification)
        _smartSensorsUpdateInterval = [[[aNotification userInfo] valueForKey:kHWMonitorSmartSensorsUpdateRate] floatValue] * 60;
    else
        _smartSensorsUpdateInterval = [_defaults floatForKey:kHWMonitorSmartSensorsUpdateRate] * 60;
        
    _smartSensorsUpdateInterval = _smartSensorsUpdateInterval > 1800 ? 1800 : _smartSensorsUpdateInterval < 300 ? 300 : _smartSensorsUpdateInterval;
    _smartSensorsLastUpdated = [NSDate dateWithTimeIntervalSince1970:0.0];
}

- (void)systemWillSleep:(NSNotification *)aNotification
{
    
}

- (void)systemDidWake:(NSNotification *)aNotification
{
    [self rebuildSensorsList];
}

- (void)willUnload
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
