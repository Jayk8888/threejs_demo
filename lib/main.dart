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
      let currentAnimationName = 'Idle';
      const SPEED = 0.03;

      let targetQ = null;
      const LOOK_SPEED = 0.1;

      window.lookAt = (x, y, z) => {
        if (currentAnimationName !== 'Still') return;
        const q = new THREE.Quaternion();
        q.setFromEuler(new THREE.Euler(x, y, z));
        targetQ = q;
      };

      window.startSpin = () => { spinning = true; };
      window.stopSpin  = () => { spinning = false; };

      window.playAnimation = (name) => {
        if (!actions[name]) return;
        if (activeAction) activeAction.fadeOut(0.3);
        activeAction = actions[name];
        activeAction.reset().fadeIn(0.3).play();
        currentAnimationName = name;
        if (name !== 'Still') {
          targetQ = null;
          spinning = false;
        }
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

          const stillClip = new THREE.AnimationClip('Still', -1, []);
          actions['Still'] = mixer.clipAction(stillClip);

          const names = [...gltf.animations.map(a => a.name), 'Still'];
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

        if (headBone && currentAnimationName === 'Still') {
          if (targetQ) {
            headBone.quaternion.slerp(targetQ, LOOK_SPEED);
          } else if (spinning) {
            headBone.rotation.y += SPEED;
          }
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
    return const MaterialApp(home: RobotPage(), debugShowCheckedModeBanner: false);
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

  final _xCtrl = TextEditingController(text: '0');
  final _yCtrl = TextEditingController(text: '0');
  final _zCtrl = TextEditingController(text: '0');

  void _startSpin() => _web?.evaluateJavascript(source: 'window.startSpin()');
  void _stopSpin()  => _web?.evaluateJavascript(source: 'window.stopSpin()');

  void _lookAt() {
    final x = double.tryParse(_xCtrl.text) ?? 0;
    final y = double.tryParse(_yCtrl.text) ?? 0;
    final z = double.tryParse(_zCtrl.text) ?? 0;
    _web?.evaluateJavascript(source: 'window.lookAt($x, $y, $z)');
  }

  void _playAnimation(String name) =>
      _web?.evaluateJavascript(source: 'window.playAnimation("$name")');

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _zCtrl.dispose();
    super.dispose();
  }

  Widget _axisField(String label, TextEditingController ctrl, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(
                signed: true, decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          Positioned.fill(
            child: InAppWebView(
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
            bottom: 40, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _axisField('X', _xCtrl, Colors.red),
                      const SizedBox(width: 12),
                      _axisField('Y', _yCtrl, Colors.green),
                      const SizedBox(width: 12),
                      _axisField('Z', _zCtrl, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _lookAt,
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Look At',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
