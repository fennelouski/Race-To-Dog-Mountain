from pathlib import Path
import json, uuid
leaf=Path(__file__).resolve().parent
folder=Path('/tmp/racedog-private-ui-20261004')
folder.mkdir(exist_ok=True)
session=str(uuid.uuid4()).upper()
(leaf/'private-ui-session.json').write_text(json.dumps({'sessionUUID':session,'suite':'com.codex.racedog.qa.'+session,'appBundle':'com.nathanfennel.RacetoDogMountain','blankHostBundle':'com.codex.RacedogQABlank','device':'4051F719-157D-4697-AED1-FEFBB7E99CA1'},indent=2)+'\n')
(folder/'Blank.swift').write_text('import SwiftUI\n@main struct Blank: App { var body: some Scene { WindowGroup { Color.clear.accessibilityIdentifier("private-blank-host") } } }\n')
src='''import XCTest

final class NativeFinishUITests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.nathanfennel.RacetoDogMountain")
    let session = "SESSION_UUID"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Actual native tree"; tree.lifetime = .keepAlways; add(tree)
        app.terminate()
    }
    func launch(largest: Bool = false) {
        app.launchArguments = ["-MountainUITests", "-MountainTestSession", session]
        if largest { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["mountain-private-qa"].waitForExistence(timeout: 10), "Private DEBUG UUID guard must be active before any interaction")
        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 5))
    }
    func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func reveal(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, "Actual control must be reachable: \\(element)")
    }
    func used() -> Int {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "tile-", "used")).count
    }
    func legal() -> XCUIElement? {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND enabled == YES", "tile-")).allElementsBoundByIndex.first { $0.isHittable }
    }
    func closeLive() {
        reveal(app.buttons["close-game"], attempts: 1)
        app.buttons["close-game"].tap()
        let back = app.buttons["Back to games"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 5))
    }
    func testARealPhoneStartContinueCompletionExportAndEffects() throws {
        launch()
        XCTAssertEqual(app.buttons["start-game"].label, "Play")
        XCTAssertTrue(app.buttons["start-game"].isHittable)
        capture("Phone first viewport Play")
        reveal(app.buttons["game-options"]); app.buttons["game-options"].tap()
        let board = app.buttons["board-size-setting-Decrement"]
        reveal(board)
        board.tap(); board.tap()
        let motion = app.switches["animations-setting"], haptics = app.switches["haptics-setting"]
        reveal(motion); reveal(haptics)
        XCTAssertEqual(motion.value as? String, "1"); XCTAssertEqual(haptics.value as? String, "1")
        motion.tap(); haptics.tap()
        app.buttons["Done"].firstMatch.tap(); app.terminate(); launch()
        reveal(app.buttons["game-options"]); app.buttons["game-options"].tap()
        reveal(motion); reveal(haptics)
        XCTAssertEqual(motion.value as? String, "0"); XCTAssertEqual(haptics.value as? String, "0")
        haptics.tap(); XCTAssertEqual(motion.value as? String, "0"); XCTAssertEqual(haptics.value as? String, "1")
        motion.tap()
        let speed = app.buttons["computer-speed-setting"]
        reveal(speed); speed.tap()
        let relaxed = app.buttons["Relaxed · 1.2 s"]
        XCTAssertTrue(relaxed.waitForExistence(timeout: 5)); relaxed.tap()
        capture("Independent saved effects and computer speed")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-")).count, 16)
        capture("Real local starting board")
        if legal() == nil { app.swipeUp() }
        guard let first = legal() else { return XCTFail("No actual legal human move") }
        first.tap()
        let resolving = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", " takes ", "points")).firstMatch
        if resolving.waitForExistence(timeout: 2) {
            capture("Actual computer resolution")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND enabled == YES", "tile-")).count, 0)
        }
        let after = Date().addingTimeInterval(8)
        while used() < 2 && Date() < after { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertGreaterThanOrEqual(used(), 2)
        let preserved = used()
        app.swipeDown(); closeLive(); app.terminate(); launch()
        XCTAssertEqual(app.buttons["start-game"].label, "Continue")
        capture("Cold launch Continue")
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), preserved)
        var humanChoices = [String]()
        let deadline = Date().addingTimeInterval(75)
        while !app.buttons["race-again"].exists && Date() < deadline {
            if let move = legal() { humanChoices.append(move.identifier); move.tap() }
            else { Thread.sleep(forTimeInterval: 0.15) }
        }
        XCTAssertTrue(app.buttons["race-again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["race-again"].isHittable && app.buttons["share-result"].isHittable)
        capture("Actual completed local game with pinned actions")
        let moves = XCTAttachment(string: humanChoices.joined(separator: "\\n")); moves.name = "Actual human button choices after Continue"; moves.lifetime = .keepAlways; add(moves)
        app.buttons["share-result"].tap()
        XCTAssertTrue(app.buttons["share-export"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.buttons["share-export"].label, "Share replay GIF")
        capture("Actual replay GIF ready")
        app.buttons["share-export"].tap()
        capture("Native share chooser without external destination")
        let shareTree = XCTAttachment(string: app.debugDescription); shareTree.name = "Native share chooser actual tree"; shareTree.lifetime = .keepAlways; add(shareTree)
        if app.buttons["Close"].firstMatch.exists { app.buttons["Close"].firstMatch.tap() }
        else if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() }
        else { app.swipeDown() }
        XCTAssertTrue(app.buttons["close-share"].waitForExistence(timeout: 5)); app.buttons["close-share"].tap()
        app.buttons["race-again"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), 0)
        capture("Race again starts an actual fresh board")
        closeLive()
    }
    func testBLargestTextFirstViewportAndActualSavedFinish() throws {
        launch(largest: true)
        let start = app.buttons["start-game"]
        XCTAssertTrue(start.isHittable && app.frame.contains(start.frame), "Largest text primary action must fit first viewport")
        capture("Largest text first viewport Continue")
        let finished = app.buttons["Finished games"]
        reveal(finished); finished.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "finished-local-")).firstMatch
        reveal(row); row.tap()
        XCTAssertTrue(app.buttons["race-again"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["race-again"].isHittable && app.buttons["share-result"].isHittable)
        XCTAssertTrue(app.frame.contains(app.buttons["race-again"].frame) && app.frame.contains(app.buttons["share-result"].frame))
        capture("Largest text actual saved finish pinned actions")
        app.buttons["race-again"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), 0)
        capture("Largest text actual replay board")
    }
}
'''.replace('SESSION_UUID',session)
(folder/'NativeFinishUITests.swift').write_text(src)
(leaf/'NativeFinishUITests.swift').write_text(src)
proj=folder/'PrivateRunner.xcodeproj';proj.mkdir(exist_ok=True)
ids={key:f'{index:024X}' for index,key in enumerate(['project','main','products','blankFile','testFile','blankProduct','testProduct','blankBuild','testBuild','blankSource','testSource','blankFramework','testFramework','blankResource','testResource','blankTarget','testTarget','proxy','dependency','projectConfig','projectDebug','projectRelease','blankConfig','blankDebug','blankRelease','testConfig','testDebug','testRelease'],1)}
i=ids
obj={}
def add(k,text):obj[i[k]]=text
add('project',f'isa=PBXProject; attributes={{LastUpgradeCheck=2600; TargetAttributes={{{i["testTarget"]}={{TestTargetID={i["blankTarget"]};}};}};}}; buildConfigurationList={i["projectConfig"]}; compatibilityVersion="Xcode 14.0"; developmentRegion=en; hasScannedForEncodings=0; knownRegions=(en,Base); mainGroup={i["main"]}; productRefGroup={i["products"]}; projectDirPath=""; projectRoot=""; targets=({i["blankTarget"]},{i["testTarget"]});')
add('main',f'isa=PBXGroup; children=({i["blankFile"]},{i["testFile"]},{i["products"]}); sourceTree="<group>";')
add('products',f'isa=PBXGroup; children=({i["blankProduct"]},{i["testProduct"]}); name=Products; sourceTree="<group>";')
for k,path,type in [('blankFile','Blank.swift','sourcecode.swift'),('testFile','NativeFinishUITests.swift','sourcecode.swift'),('blankProduct','Blank.app','wrapper.application'),('testProduct','NativeFinishUITests.xctest','wrapper.cfbundle')]:add(k,f'isa=PBXFileReference; lastKnownFileType={type}; path="{path}"; sourceTree={"BUILT_PRODUCTS_DIR" if "Product" in k else chr(34)+"<group>"+chr(34)};')
for k,ref in [('blankBuild','blankFile'),('testBuild','testFile')]:add(k,f'isa=PBXBuildFile; fileRef={i[ref]};')
for prefix in ['blank','test']:
 for suffix,isa,files in [('Source','PBXSourcesBuildPhase',i[prefix+'Build']),('Framework','PBXFrameworksBuildPhase',''),('Resource','PBXResourcesBuildPhase','')]:add(prefix+suffix,f'isa={isa}; buildActionMask=2147483647; files=({files}); runOnlyForDeploymentPostprocessing=0;')
add('proxy',f'isa=PBXContainerItemProxy; containerPortal={i["project"]}; proxyType=1; remoteGlobalIDString={i["blankTarget"]}; remoteInfo=Blank;')
add('dependency',f'isa=PBXTargetDependency; target={i["blankTarget"]}; targetProxy={i["proxy"]};')
for prefix,name,ptype in [('blank','Blank','application'),('test','NativeFinishUITests','bundle.ui-testing')]:add(prefix+'Target',f'isa=PBXNativeTarget; buildConfigurationList={i[prefix+"Config"]}; buildPhases=({i[prefix+"Source"]},{i[prefix+"Framework"]},{i[prefix+"Resource"]}); buildRules=(); dependencies=({i["dependency"] if prefix=="test" else ""}); name={name}; productName={name}; productReference={i[prefix+"Product"]}; productType="com.apple.product-type.{ptype}";')
base='SDKROOT=iphoneos; IPHONEOS_DEPLOYMENT_TARGET=17.0; SWIFT_VERSION=5.0; CLANG_ENABLE_MODULES=YES; CLANG_ENABLE_OBJC_ARC=YES; ENABLE_BITCODE=NO; TARGETED_DEVICE_FAMILY="1,2";'
for prefix in ['project','blank','test']:
 add(prefix+'Config',f'isa=XCConfigurationList; buildConfigurations=({i[prefix+"Debug"]},{i[prefix+"Release"]}); defaultConfigurationIsVisible=0; defaultConfigurationName=Release;')
 for cfg in ['Debug','Release']:
  settings=base+' SWIFT_OPTIMIZATION_LEVEL='+('"-Onone"' if cfg=='Debug' else '"-O"')+';'
  if prefix!='project':
   settings+=' GENERATE_INFOPLIST_FILE=YES; CODE_SIGN_STYLE=Automatic; PRODUCT_NAME="$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER='+('com.codex.RacedogQABlank' if prefix=='blank' else 'com.codex.RacedogPrivateUITests')+'; LD_RUNPATH_SEARCH_PATHS="$(inherited) @executable_path/Frameworks @loader_path/Frameworks";'
   if prefix=='blank':settings+=' INFOPLIST_KEY_UILaunchScreen_Generation=YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation=YES;'
   else:settings+=' TEST_TARGET_NAME=Blank;'
  add(prefix+cfg,f'isa=XCBuildConfiguration; buildSettings={{{settings}}}; name={cfg};')
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1; classes={}; objectVersion=56; objects={\n'+''.join(k+'={'+v+'};\n' for k,v in obj.items())+'}; rootObject='+i['project']+';}\n')
sch=proj/'xcshareddata/xcschemes';sch.mkdir(parents=True,exist_ok=True)
def ref(prefix,name,buildname):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i[prefix+"Target"]}" BuildableName="{buildname}" BlueprintName="{name}" ReferencedContainer="container:PrivateRunner.xcodeproj"/>'
(sch/'PrivateRunner.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2600" version="1.7"><BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref('blank','Blank','Blank.app')}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref('test','NativeFinishUITests','NativeFinishUITests.xctest')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('test','NativeFinishUITests','NativeFinishUITests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref('blank','Blank','Blank.app')}</BuildableProductRunnable></LaunchAction><AnalyzeAction buildConfiguration="Debug"/></Scheme>''')
print(folder);print(session)
