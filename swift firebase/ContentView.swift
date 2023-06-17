import SwiftUI
import Firebase
import FirebaseStorage
import UIKit
import AVFoundation

struct ContentView: View {
    @State private var uploadedImage: Image?
    @State private var showImagePicker = false
    @State private var isCameraActive = false
    @State private var selectedImage: UIImage?
    @State private var imageName = ""

    var body: some View {
        VStack {
            if let image = uploadedImage {
                image
                    .resizable()
                    .frame(width: 200, height: 200)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .frame(width: 200, height: 200)
            }

            Button(action: {
                showImagePicker = true
            }) {
                Text("画像を選択")
            }

            Button(action: {
                isCameraActive = true
            }) {
                Text("カメラを起動")
            }

            Button(action: {
                uploadImage()
            }) {
                Text("画像をアップロード")
            }

            Button(action: {
                downloadImage()
            }) {
                Text("画像をダウンロード")
            }

            Button(action: {
                takePhoto()
            }) {
                Text("写真を撮る")
            }
        }
        .padding()
        .onAppear {
            FirebaseApp.configure()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, showImagePicker: $showImagePicker, imageName: $imageName)
        }
        .fullScreenCover(isPresented: $isCameraActive, content: {
            CameraView(isActive: $isCameraActive, selectedImage: $selectedImage)
        })
    }

    func uploadImage() {
        guard let image = selectedImage else {
            print("画像が選択されていません")
            return
        }

        if let imageData = image.jpegData(compressionQuality: 1.0) {
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("images/\(imageName).jpg")

            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("画像のアップロードエラー: \(error.localizedDescription)")
                } else {
                    print("画像が正常にアップロードされました")
                    self.downloadImage()
                }
            }
        }
    }

    func downloadImage() {
        let storageRef = Storage.storage().reference().child("images/\(imageName).jpg")

        storageRef.downloadURL { url, error in
            if let error = error {
                print("画像のダウンロードエラー: \(error.localizedDescription)")
            } else if let url = url {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("画像のダウンロードエラー: \(error.localizedDescription)")
                    } else if let data = data {
                        if let uiImage = UIImage(data: data) {
                            self.uploadedImage = Image(uiImage: uiImage)
                        }
                    }
                }.resume()
            }
        }
    }

    func takePhoto() {
        isCameraActive = true
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var imageName: String

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = context.coordinator
        imagePicker.sourceType = .camera
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 更新は不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                print("画像の取得エラー")
                picker.dismiss(animated: true, completion: nil)
                return
            }

            parent.image = image
            parent.showImagePicker = false
            parent.imageName = generateRandomName() // ランダムな名前を生成して設定
            picker.dismiss(animated: true, completion: nil)
        }
    }
}


struct CameraView: UIViewControllerRepresentable {
    @Binding var isActive: Bool
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraViewController = CameraViewController()
        cameraViewController.delegate = context.coordinator
        return cameraViewController
    }

    func updateUIViewController(_ cameraViewController: CameraViewController, context: Context) {
        if isActive {
            cameraViewController.startCamera()
        } else {
            cameraViewController.stopCamera()
        }
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func didFinishTaking(photo: UIImage?) {
            parent.selectedImage = photo
            parent.isActive = false
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didFinishTaking(photo: UIImage?)
}


class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    weak var delegate: CameraViewControllerDelegate?
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("カメラのセットアップに失敗しました")
            return
        }

        captureSession.beginConfiguration()

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }

    func startCamera() {
        captureSession.startRunning()
    }

    func stopCamera() {
        captureSession.stopRunning()
    }

    private func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func handleCapturedPhoto(_ photo: UIImage?) {
        delegate?.didFinishTaking(photo: photo)
    }

    @IBAction func captureButtonTapped(_ sender: UIButton) {
        takePhoto()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) {
            handleCapturedPhoto(capturedImage)
        } else {
            handleCapturedPhoto(nil)
        }
    }
}

// ランダムな名前を生成する関数
func generateRandomName() -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let nameLength = 10

    let randomName = String((0..<nameLength).map { _ in
        letters.randomElement()!
    })

    return randomName
}

