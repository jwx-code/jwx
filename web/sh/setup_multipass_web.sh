 #
//  setup_multipass_web.sh
//  jwx
//
//  Created by Jonas wrede on 15.08.25.
//

multipass launch --name web --cpus 1 --mem 1G --disk 5G --cloud-init apache.yaml

multipass info web | grep -i IPv4
