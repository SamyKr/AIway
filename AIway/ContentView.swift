//
//  ContentView.swift
//  AIway
//
//  Created by Samy 📍 on 23/04/2025.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation
import Vision

// Viewmodel class to hold the data for detecte object we can add other information later..

struct DetectedObject: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}

class CameraViewModel : ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
}

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            CameraView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            // Affichage des objets détectés
            ForEach(viewModel.detectedObjects) { obj in
                ZStack(alignment: .topLeading) {
                    // Bounding box rouge
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(width: obj.boundingBox.width, height: obj.boundingBox.height)
                        .position(x: obj.boundingBox.midX, y: obj.boundingBox.midY)

                    // Étiquette avec nom + confiance
                    Text("\(obj.label) \(String(format: "%.0f", obj.confidence * 100))%")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                        .position(x: obj.boundingBox.minX + 5, y: obj.boundingBox.minY + 5)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
// The view that displays the camera feed using UIViewControlerRepresentabel

struct CameraView : UIViewControllerRepresentable {
    @ObservedObject var viewModel : CameraViewModel //use the ViewModel
    //create the UIViewController that will be used for the camera feed
    func makeUIViewController(context: Context) -> UIViewController {
        let cameraViewController = CameraViewController(viewModel:viewModel)
        return cameraViewController
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
        
    }
    class CameraViewController : UIViewController {
        var captureSession : AVCaptureSession!
        var previewLayer : AVCaptureVideoPreviewLayer! //The layer that shows the camera feed on screen
        var viewModel : CameraViewModel
        init(viewModel:CameraViewModel){
            self.viewModel = viewModel
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder:NSCoder){
            fatalError("init(coder:) has not been implemented")
        }
        override func viewDidLoad() {
            super.viewDidLoad()
            captureSession=AVCaptureSession()
            captureSession.beginConfiguration()
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else{
                return
            }
            captureSession.addInput(videoInput)
            let videoOutput=AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label:"CameraQueue"))
            captureSession.addOutput(videoOutput)
            //Set up the camera preview layer and add it to the view
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame=view.layer.bounds
            view.layer.addSublayer(previewLayer)
            //Commit the camera configuration and start the session
            captureSession.commitConfiguration()
            captureSession.startRunning()
            
            
        }
}
    
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    func detectObject(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let model = try? VNCoreMLModel(for: YOLOv3().model) else { return }

        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }

            var newDetections: [DetectedObject] = []

            for result in results {
                if result.confidence > 0.3, let label = result.labels.first {
                    let box = self.convertBBox(result.boundingBox)
                    let detected = DetectedObject(label: label.identifier, confidence: label.confidence, boundingBox: box)
                    newDetections.append(detected)
                }
            }

            DispatchQueue.main.async {
                self.viewModel.detectedObjects = newDetections
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
 func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
     detectObject(sampleBuffer: sampleBuffer)
}
func convertBBox(_ boundingBox: CGRect) -> CGRect {
    let width = previewLayer.frame.width
    let height = previewLayer.frame.height

    // Conversion des coordonnées normalisées en coordonnées de pixels
    let x = boundingBox.origin.x * width
    let y = (1 - boundingBox.origin.y - boundingBox.size.height) * height
    let w = boundingBox.size.width * width
    let h = boundingBox.size.height * height

    return CGRect(x: x, y: y, width: w, height: h)
    }
}
