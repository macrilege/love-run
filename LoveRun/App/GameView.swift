import SpriteKit
import SwiftUI

struct GameView: View {
    private let scene: LoveRunScene = {
        let scene = LoveRunScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden)
            .statusBarHidden()
    }
}
