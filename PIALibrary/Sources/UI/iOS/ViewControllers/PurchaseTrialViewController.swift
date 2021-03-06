//
//  PurchaseTrialViewController.swift
//  PIALibrary-iOS
//
//  Created by Jose Antonio Blaya Garcia on 06/08/2019.
//  Copyright © 2020 Private Internet Access, Inc.
//
//  This file is part of the Private Internet Access iOS Client.
//
//  The Private Internet Access iOS Client is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The Private Internet Access iOS Client is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License along with the Private
//  Internet Access iOS Client.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit

class PurchaseTrialViewController: AutolayoutViewController, BrandableNavigationBar, WelcomeChild {
    
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var textAgreement: UITextView!
    @IBOutlet private weak var buttonPurchase: PIAButton!
    @IBOutlet private weak var buttonMorePlans: PIAButton!
    @IBOutlet private weak var buttonTrialTerms: PIAButton!

    @IBOutlet private weak var headerTitleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var smallTitleLabel: UILabel!

    @IBOutlet private weak var protectionImageView: UIImageView!
    @IBOutlet private weak var protectionTitleLabel: UILabel!
    @IBOutlet private weak var protectionSubtitleLabel: UILabel!

    @IBOutlet private weak var devicesImageView: UIImageView!
    @IBOutlet private weak var devicesTitleLabel: UILabel!
    @IBOutlet private weak var devicesSubtitleLabel: UILabel!

    @IBOutlet private weak var serversImageView: UIImageView!
    @IBOutlet private weak var serversTitleLabel: UILabel!
    @IBOutlet private weak var serversSubtitleLabel: UILabel!

    var preset: Preset?
    weak var completionDelegate: WelcomeCompletionDelegate?
    var omitsSiblingLink = false
    
    private var allPlans: [PurchasePlan] = [.dummy, .dummy]
    
    private var selectedPlanIndex: Int?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        styleButtons()

        guard let _ = self.preset else {
            fatalError("Preset not propagated")
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: Theme.current.palette.navigationBarBackIcon?.withRenderingMode(.alwaysOriginal),
            style: .plain,
            target: self,
            action: #selector(back(_:))
        )
        self.navigationItem.leftBarButtonItem?.accessibilityLabel = L10n.Welcome.Redeem.Accessibility.back

        headerTitleLabel.text = L10n.Signup.Purchase.Trials.intro
        subtitleLabel.text = L10n.Signup.Purchase.Trials.Price.after("")
        smallTitleLabel.text = L10n.Signup.Purchase.Trials.Money.back
        
        protectionTitleLabel.text = L10n.Signup.Purchase.Trials._1year.protection
        protectionSubtitleLabel.text = L10n.Signup.Purchase.Trials.anonymous
        protectionImageView.image = Asset.shieldIcon.image.withRenderingMode(.alwaysTemplate)
        
        devicesTitleLabel.text = L10n.Signup.Purchase.Trials.devices
        devicesSubtitleLabel.text = L10n.Signup.Purchase.Trials.Devices.description
        devicesImageView.image = Asset.computerIcon.image.withRenderingMode(.alwaysTemplate)
        
        serversTitleLabel.text = L10n.Signup.Purchase.Trials.region
        serversSubtitleLabel.text = L10n.Signup.Purchase.Trials.servers
        serversImageView.image = Asset.globeIcon.image.withRenderingMode(.alwaysTemplate)
        
        textAgreement.attributedText = Theme.current.agreementText(
            withMessage: L10n.Welcome.Agreement.message(""),
            tos: L10n.Welcome.Agreement.Message.tos,
            tosUrl: Client.configuration.tosUrl,
            privacy: L10n.Welcome.Agreement.Message.privacy,
            privacyUrl: Client.configuration.privacyUrl
        )
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(productsDidFetch(notification:)), name: .__InAppDidFetchProducts, object: nil)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let products = preset?.accountProvider.planProducts {
            refreshPlans(products)
        } else {
            disableInteractions(fully: false)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == StoryboardSegue.Welcome.confirmPurchaseVPNPlanSegue.rawValue) {
            if let vc = segue.destination as? ConfirmVPNPlanViewController,
                let selectedIndex = selectedPlanIndex {
                vc.preset = preset
                vc.completionDelegate = completionDelegate
                vc.populateViewWith(plans: allPlans,
                                    andSelectedPlanIndex: selectedIndex)
            }
        } else if (segue.identifier == StoryboardSegue.Welcome.viewMoreVPNPlansSegue.rawValue) {
            if let vc = segue.destination as? PurchaseViewController {
                vc.preset = preset
                vc.completionDelegate = completionDelegate
            }
        } else if (segue.identifier == StoryboardSegue.Welcome.showTermsAndConditionsSegue.rawValue) {
            if let vc = segue.destination as? TermsAndConditionsViewController {
                vc.termsAndConditionsTitle = L10n.Welcome.Agreement.Trials.title
                vc.termsAndConditions = L10n.Welcome.Agreement.Trials.message
            }
        }
    }
    
    // MARK: Actions
    
    private func refreshPlans(_ plans: [Plan: InAppProduct]) {
        if let yearly = plans[.yearly] {
            let purchase = PurchasePlan(
                plan: .yearly,
                product: yearly,
                monthlyFactor: 12.0
            )
            
            purchase.title = L10n.Welcome.Plan.Yearly.title
            let currencySymbol = purchase.product.priceLocale.currencySymbol ?? ""
            purchase.detail = L10n.Welcome.Plan.Yearly.detailFormat(currencySymbol, purchase.product.price.description)
            purchase.bestValue = true
            let price = L10n.Welcome.Plan.Yearly.detailFormat(currencySymbol, purchase.product.price.description)

            DispatchQueue.main.async { [weak self] in
                if let label = self?.subtitleLabel {
                    label.text = L10n.Signup.Purchase.Trials.Price.after(price)
                    Theme.current.makeSmallLabelToStandOut(label,
                                                           withTextToStandOut: price)
                }
            }
            allPlans[0] = purchase
            selectedPlanIndex = 0
        }
    }
    
    private func disableInteractions(fully: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showLoadingAnimation()
        }
        if fully {
            parent?.view.isUserInteractionEnabled = false
        }
    }
    
    private func enableInteractions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hideLoadingAnimation()
        }
        parent?.view.isUserInteractionEnabled = true
    }
    
    // MARK: Notifications
    
    @objc private func productsDidFetch(notification: Notification) {
        let products: [Plan: InAppProduct] = notification.userInfo(for: .products)
        refreshPlans(products)
        enableInteractions()
    }
    
    // MARK: Restylable
    
    override func viewShouldRestyle() {
        super.viewShouldRestyle()
        navigationItem.titleView = NavigationLogoView()
        Theme.current.applyNavigationBarStyle(to: self)
        Theme.current.applyPrincipalBackground(view)
        Theme.current.applyLinkAttributes(textAgreement)
        Theme.current.applyBigTitle(headerTitleLabel, appearance: .dark)
        Theme.current.applySmallSubtitle(smallTitleLabel)
        Theme.current.applySubtitle(subtitleLabel)

        if Theme.current.palette.appearance == .light {
            protectionImageView.tintColor = Theme.current.palette.lineColor
            devicesImageView.tintColor = Theme.current.palette.lineColor
            serversImageView.tintColor = Theme.current.palette.lineColor
        } else {
            protectionImageView.tintColor = .white
            devicesImageView.tintColor = .white
            serversImageView.tintColor = .white
        }
        
        Theme.current.applySettingsCellTitle(protectionTitleLabel, appearance: .dark)
        Theme.current.applySmallSubtitle(protectionSubtitleLabel)
        
        Theme.current.applySettingsCellTitle(devicesTitleLabel, appearance: .dark)
        Theme.current.applySmallSubtitle(devicesSubtitleLabel)

        Theme.current.applySettingsCellTitle(serversTitleLabel, appearance: .dark)
        Theme.current.applySmallSubtitle(serversSubtitleLabel)

    }
    
    private func styleButtons() {
        buttonPurchase.setRounded()
        buttonMorePlans.setRounded()
        buttonPurchase.style(style: TextStyle.Buttons.piaGreenButton)
        buttonMorePlans.style(style: TextStyle.Buttons.piaPlainTextButton)
        buttonTrialTerms.style(style: TextStyle.Buttons.piaSmallPlainTextButton)
        buttonPurchase.setTitle(L10n.Signup.Purchase.Trials.start.uppercased(),
                                for: [])
        buttonMorePlans.setTitle(L10n.Signup.Purchase.Trials.All.plans,
                                for: [])
        buttonTrialTerms.setTitle(L10n.Welcome.Agreement.Trials.title,
                                 for: [])
        Theme.current.applyTransparentButton(buttonMorePlans,
                                             withSize: 1.0)
        Theme.current.applyTransparentButton(buttonTrialTerms,
                                             withSize: 0.0)
    }
    
}
