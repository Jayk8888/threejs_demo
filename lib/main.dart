import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String kHtml = '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <style>
      * { margin: 0; padding: 0; }
      body { background: #e0e0e0; overflow: hidden; }
    </style>
  </head>
  <body>
    <script type="importmap">
      { "imports": {
          "three": "https://unpkg.com/three@0.158.0/build/three.module.js",
          "three/addons/": "https://unpkg.com/three@0.158.0/examples/jsm/"
      }}
    </script>
    <script type="module">
      import * as THREE from 'three';
      import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
      import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0xe0e0e0);

      const camera = new THREE.PerspectiveCamera(45, innerWidth / innerHeight, 0.25, 100);
      camera.position.set(-5, 3, 10);
      camera.lookAt(0, 2, 0);

      const renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setPixelRatio(devicePixelRatio);
      renderer.setSize(innerWidth, innerHeight);
      document.body.appendChild(renderer.domElement);

      const controls = new OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.target.set(0, 2, 0);

      const hemi = new THREE.HemisphereLight(0xffffff, 0x8d8d8d, 3);
      hemi.position.set(0, 20, 0);
      scene.add(hemi);
      const dir = new THREE.DirectionalLight(0xffffff, 3);
      dir.position.set(0, 20, 10);
      scene.add(dir);

      const ground = new THREE.Mesh(
        new THREE.PlaneGeometry(2000, 2000),
        new THREE.MeshPhongMaterial({ color: 0xcbcbcb, depthWrite: false })
      );
      ground.rotation.x = -Math.PI / 2;
      scene.add(ground);
      const grid = new THREE.GridHelper(200, 40, 0x000000, 0x000000);
      grid.material.opacity = 0.2;
      grid.material.transparent = true;
      scene.add(grid);

      let spinning = false;
      let headBone = null;
      let mixer = null;
      let actions = {};
      let activeAction = null;
      const SPEED = 0.03;

      window.startSpin = () => { spinning = true; };
      window.stopSpin  = () => { spinning = false; };

      window.playAnimation = (name) => {
        if (!actions[name]) return;
        if (activeAction) activeAction.fadeOut(0.3);
        activeAction = actions[name];
        activeAction.reset().fadeIn(0.3).play();
      };

      new GLTFLoader().load(
        'https://threejs.org/examples/models/gltf/RobotExpressive/RobotExpressive.glb',
        (gltf) => {
          const model = gltf.scene;
          scene.add(model);

          mixer = new THREE.AnimationMixer(model);

          gltf.animations.forEach((clip) => {
            const action = mixer.clipAction(clip);
            const oneShot = ['Jump','Yes','No','Wave','Punch','ThumbsUp','Death'];
            if (oneShot.includes(clip.name)) {
              action.loop = THREE.LoopOnce;
              action.clampWhenFinished = true;
            }
            actions[clip.name] = action;
          });

          const names = gltf.animations.map(a => a.name);
          window.flutter_inappwebview.callHandler('onAnimationsLoaded', JSON.stringify(names));

          activeAction = actions['Idle'];
          if (activeAction) activeAction.play();

          model.traverse((obj) => {
            if (obj.isBone && obj.name === 'Head') headBone = obj;
          });
        }
      );

      const clock = new THREE.Clock();
      function animate() {
        requestAnimationFrame(animate);
        const dt = clock.getDelta();
        if (mixer) mixer.update(dt);
        if (headBone && spinning) {
          headBone.rotation.y += SPEED;
        }
        controls.update();
        renderer.render(scene, camera);
      }
      animate();

      window.addEventListener('resize', () => {
        camera.aspect = innerWidth / innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(innerWidth, innerHeight);
      });
    </script>
  </body>
</html>
''';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: RobotPage(),debugShowCheckedModeBanner: false);
  }
}

class RobotPage extends StatefulWidget {
  const RobotPage({super.key});
  @override
  State<RobotPage> createState() => _RobotPageState();
}

class _RobotPageState extends State<RobotPage> {
  InAppWebViewController? _web;
  List<String> _animations = [];
  String? _selected;

  void _startSpin() => _web?.evaluateJavascript(source: 'window.startSpin()');
  void _stopSpin()  => _web?.evaluateJavascript(source: 'window.stopSpin()');

  void _playAnimation(String name) =>
      _web?.evaluateJavascript(source: 'window.playAnimation("$name")');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(data: kHtml),
            initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
            onWebViewCreated: (c) {
              _web = c;
              c.addJavaScriptHandler(
                handlerName: 'onAnimationsLoaded',
                callback: (args) {
                  final List<String> names =
                      List<String>.from(jsonDecode(args[0] as String));
                  setState(() {
                    _animations = names;
                    _selected = names.contains('Idle') ? 'Idle' : names.first;
                  });
                },
              );
            },
          ),

          if (_animations.isNotEmpty)
            Positioned(
              top: 40, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selected,
                    items: _animations
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                    onChanged: (name) {
                      if (name == null) return;
                      setState(() => _selected = name);
                      _playAnimation(name);
                    },
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTapDown:   (_) => _startSpin(),
                onTapUp:     (_) => _stopSpin(),
                onTapCancel:    () => _stopSpin(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Hold to Spin Head',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
