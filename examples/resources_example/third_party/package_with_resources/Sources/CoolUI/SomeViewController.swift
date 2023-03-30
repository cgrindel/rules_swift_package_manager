import UIKit

public class SomeViewController: UIViewController {
    
    public override func loadView() {
        self.view = UIView()
        
        let label = UILabel()
        label.textColor = .white
        label.text = moduleLocalized("Title")
        
        let imageView = UIImageView()
        imageView.image = moduleImage("avatar")
        
        let stack = UIStackView(arrangedSubviews: [label, imageView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            
            imageView.widthAnchor.constraint(equalToConstant: 200),
            imageView.heightAnchor.constraint(equalToConstant: 200),
        ])
    }
}
