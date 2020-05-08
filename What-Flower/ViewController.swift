//
//  ViewController.swift
//  What-Flower
//
//  Created by Azure May Burmeister on 3/27/20.
//  Copyright © 2020 Azure May Burmeister. All rights reserved.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageLabel: UILabel!
    private let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            imageView.image = selectedImage
            guard let ciImage = CIImage(image: selectedImage) else {
                fatalError("Converting UIImage to CIImage failed")
            }
            classifyImage(ciImage)
        }
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    private func classifyImage(_ image: CIImage) {
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Loading CoreML Model Failed")
        }
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError("Model failed to process image")
            }
            if let topResult = results.first?.identifier.capitalized {
                self.navigationItem.title = topResult
                self.wikiFetch(topResult)
            }
        }
        let handler = VNImageRequestHandler(ciImage: image)
        do {
            try handler.perform([request])
        } catch {
            print("Error handling VNCoreModel request \(error)")
        }
    }

    @IBAction func cameraButtonPressed(_ sender: UIBarButtonItem) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    private func wikiFetch(_ flowerName: String) {
        let redirector = Redirector(behavior: .follow)
        let wikipediaURl = "https://en.wikipedia.org/w/api.php"
        let parameters : [String:String] = [
            "format" : "json",
            "action" : "query",
            "prop" : "extracts|pageimages",
            "pithumbsize" : "500",
            "exintro" : "",
            "explaintext" : "",
            "titles" : flowerName,
            "indexpageids" : "",
            "redirects" : "1"
        ]
        AF.request(wikipediaURl, method: .get, parameters: parameters).redirect(using: redirector).responseJSON { (response) in
            if response.error != nil {
                print("Error processing request")
                return
            }
            if let result = response.data {
                let json = JSON(result)
                self.displayResult(json)
            }
        }
    }
    
    private func displayResult(_ json: JSON) {
        if let pageID = json["query"]["pageids"][0].string {
            let pageData = json["query"]["pages"][pageID]
            let title = pageData["title"].stringValue
            let extract = pageData["extract"].stringValue
            imageLabel.text = extract
            self.navigationItem.title = title.capitalized
            if let imageSource = pageData["thumbnail"]["source"].string {
                self.imageView.sd_setImage(with: URL(string: imageSource))
            }
        }
    }
}
