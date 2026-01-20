import Foundation

// MARK: - Specialty Pack Definition

struct SpecialtyPack: Identifiable, Codable {
    let id: String
    let name: String
    let shortName: String
    let type: TrainingType
    let categories: [PackCategory]
    let defaultAccessSites: [AccessSite]
    let defaultComplications: [Complication]
    
    enum TrainingType: String, Codable, CaseIterable {
        case fellowship = "Fellowship"
        case residency = "Residency"
    }
}

struct PackCategory: Identifiable, Codable {
    let id: String
    let category: ProcedureCategory
    let procedures: [ProcedureTag]
}

struct ProcedureTag: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let isClosureDevice: Bool
    let subOptions: [String]?  // For procedures requiring site selection
    let allowsCustomSubOption: Bool  // For "Other (free text)" option
    
    init(id: String, title: String, isClosureDevice: Bool = false, subOptions: [String]? = nil, allowsCustomSubOption: Bool = false) {
        self.id = id
        self.title = title
        self.isClosureDevice = isClosureDevice
        self.subOptions = subOptions
        self.allowsCustomSubOption = allowsCustomSubOption
    }
    
    var hasSubOptions: Bool {
        subOptions != nil && !(subOptions?.isEmpty ?? true)
    }
}

// MARK: - Specialty Pack Catalog

struct SpecialtyPackCatalog {
    
    // MARK: - All Packs
    
    static let allPacks: [SpecialtyPack] = [
        interventionalCardiology,
        electrophysiology,
        cardiacImaging,
        gastroenterology,
        pulmonaryCriticalCare,
        nephrology,
        generalSurgery,
        orthopedicSurgery,
        emergencyMedicine,
        anesthesiology,
        obgyn,
        neurosurgery,
        cardiothoracicSurgery,
        vascularSurgery,
        plasticSurgery,
        urology,
        entOtolaryngology,
        ophthalmology,
        internalMedicine,
        familyMedicine,
        pediatrics,
        dermatology,
        painMedicine,
        interventionalRadiology
    ]
    
    static func pack(for id: String) -> SpecialtyPack? {
        allPacks.first { $0.id == id }
    }
    
    static func packs(for type: SpecialtyPack.TrainingType) -> [SpecialtyPack] {
        allPacks.filter { $0.type == type }
    }

    /// Find procedure title by ID across all packs
    static func findProcedureTitle(for procedureId: String) -> String? {
        for pack in allPacks {
            for category in pack.categories {
                if let procedure = category.procedures.first(where: { $0.id == procedureId }) {
                    return procedure.title
                }
            }
        }
        return nil
    }

    // MARK: - Interventional Cardiology
    
    static let interventionalCardiology = SpecialtyPack(
        id: "interventional-cardiology",
        name: "Interventional Cardiology",
        shortName: "IC",
        type: .fellowship,
        categories: [
            PackCategory(id: "ic-dx", category: .cardiacDiagnostic, procedures: [
                ProcedureTag(id: "ic-dx-lhc", title: "Left Heart Catheterization"),
                ProcedureTag(id: "ic-dx-rhc", title: "Right Heart Catheterization"),
                ProcedureTag(id: "ic-dx-coro", title: "Coronary Angiography"),
                ProcedureTag(id: "ic-dx-lv", title: "LV Angiography"),
                ProcedureTag(id: "ic-dx-ao", title: "Aortography"),
                ProcedureTag(id: "ic-dx-biopsy", title: "Endomyocardial Biopsy")
            ]),
            PackCategory(id: "ic-pci", category: .coronaryIntervention, procedures: [
                ProcedureTag(id: "ic-pci-stent", title: "Coronary Stent"),
                ProcedureTag(id: "ic-pci-poba", title: "POBA"),
                ProcedureTag(id: "ic-pci-dcb", title: "DCB"),
                ProcedureTag(id: "ic-pci-rotablator", title: "Rotational Atherectomy"),
                ProcedureTag(id: "ic-pci-orbital", title: "Orbital Atherectomy"),
                ProcedureTag(id: "ic-pci-laser", title: "Laser Atherectomy"),
                ProcedureTag(id: "ic-pci-ivl", title: "Intravascular Lithotripsy"),
                ProcedureTag(id: "ic-pci-thrombectomy", title: "Thrombectomy"),
                ProcedureTag(id: "ic-pci-ivus", title: "IVUS"),
                ProcedureTag(id: "ic-pci-oct", title: "OCT"),
                ProcedureTag(id: "ic-pci-ffr", title: "FFR/iFR"),
                ProcedureTag(id: "ic-pci-ice", title: "ICE")
            ]),
            PackCategory(id: "ic-periph", category: .peripheralArterial, procedures: [
                ProcedureTag(id: "ic-periph-renal", title: "Renal Angiography/Intervention"),
                ProcedureTag(id: "ic-periph-iliac", title: "Iliac Intervention"),
                ProcedureTag(id: "ic-periph-fem", title: "Femoral Intervention"),
                ProcedureTag(id: "ic-periph-pop", title: "Popliteal Intervention"),
                ProcedureTag(id: "ic-periph-btk", title: "Below-the-Knee Intervention"),
                ProcedureTag(id: "ic-periph-carotid", title: "Carotid Angiography/Intervention"),
                ProcedureTag(id: "ic-periph-ather", title: "Peripheral Atherectomy")
            ]),
            PackCategory(id: "ic-venous", category: .venousPE, procedures: [
                ProcedureTag(id: "ic-venous-pe-cdt", title: "PE CDT/Thrombectomy"),
                ProcedureTag(id: "ic-venous-ivc", title: "IVC Filter Placement"),
                ProcedureTag(id: "ic-venous-ivc-rem", title: "IVC Filter Retrieval"),
                ProcedureTag(id: "ic-venous-dvt", title: "DVT Intervention"),
                ProcedureTag(id: "ic-venous-cardiomems", title: "CardioMems Implant")
            ]),
            PackCategory(id: "ic-struct", category: .structuralValve, procedures: [
                ProcedureTag(id: "ic-struct-tavr", title: "TAVR"),
                ProcedureTag(id: "ic-struct-bav", title: "Balloon Aortic Valvuloplasty"),
                ProcedureTag(id: "ic-struct-bmv", title: "Balloon Mitral Valvuloplasty"),
                ProcedureTag(id: "ic-struct-teer", title: "TEER (MitraClip/PASCAL)"),
                ProcedureTag(id: "ic-struct-watchman", title: "LAAO (Watchman/Amulet)"),
                ProcedureTag(id: "ic-struct-pfo", title: "PFO Closure"),
                ProcedureTag(id: "ic-struct-asd", title: "ASD Closure"),
                ProcedureTag(id: "ic-struct-vsd", title: "VSD Closure"),
                ProcedureTag(id: "ic-struct-paravalv", title: "Paravalvular Leak Closure"),
                ProcedureTag(id: "ic-struct-alcohol", title: "Alcohol Septal Ablation"),
                ProcedureTag(id: "ic-struct-pericardio", title: "Pericardiocentesis")
            ]),
            PackCategory(id: "ic-aortic", category: .aortic, procedures: [
                ProcedureTag(id: "ic-aortic-tevar", title: "TEVAR"),
                ProcedureTag(id: "ic-aortic-evar", title: "EVAR"),
                ProcedureTag(id: "ic-aortic-coarc", title: "Coarctation Intervention")
            ]),
            PackCategory(id: "ic-mcs", category: .mcs, procedures: [
                ProcedureTag(id: "ic-mcs-iabp", title: "IABP"),
                ProcedureTag(id: "ic-mcs-impella", title: "Impella"),
                ProcedureTag(id: "ic-mcs-ecmo-va", title: "VA-ECMO Cannulation"),
                ProcedureTag(id: "ic-mcs-ecmo-vv", title: "VV-ECMO"),
                ProcedureTag(id: "ic-mcs-tandem", title: "TandemHeart/Protek Duo")
            ]),
            PackCategory(id: "ic-ep", category: .ep, procedures: [
                ProcedureTag(id: "ic-ep-temp", title: "Temporary Pacemaker"),
                ProcedureTag(id: "ic-ep-transvenous", title: "Transvenous Pacemaker")
            ]),
            PackCategory(id: "ic-bedside", category: .bedside, procedures: [
                ProcedureTag(id: "ic-bedside-cvl", title: "Central Line"),
                ProcedureTag(id: "ic-bedside-transvenous", title: "Transvenous Pacemaker"),
                ProcedureTag(id: "ic-bedside-iabp", title: "IABP"),
                ProcedureTag(id: "ic-bedside-vaecmo", title: "VA ECMO"),
                ProcedureTag(id: "ic-bedside-vvecmo", title: "VV ECMO")
            ]),
            PackCategory(id: "ic-closure", category: .closureDevices, procedures: [
                ProcedureTag(id: "ic-closure-angio", title: "Angioseal", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-mynx", title: "Mynx", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-perclose", title: "Perclose", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-proglide", title: "ProGlide", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-manta", title: "MANTA", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-vascade", title: "Vascade", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-manual", title: "Manual Compression", isClosureDevice: true),
                ProcedureTag(id: "ic-closure-tr", title: "TR Band", isClosureDevice: true)
            ])
        ],
        defaultAccessSites: [.femoral, .radial, .brachial, .pedal, .pericardial, .transseptal],
        defaultComplications: [.bleeding, .vascular, .stroke, .renalInjury, .tamponade, .mi, .death]
    )
    
    // MARK: - Electrophysiology
    
    static let electrophysiology = SpecialtyPack(
        id: "electrophysiology",
        name: "Cardiac Electrophysiology",
        shortName: "EP",
        type: .fellowship,
        categories: [
            PackCategory(id: "ep-dx", category: .epDiagnostic, procedures: [
                ProcedureTag(id: "ep-dx-eps", title: "Electrophysiology Study"),
                ProcedureTag(id: "ep-dx-mapping", title: "Electroanatomic Mapping")
            ]),
            PackCategory(id: "ep-ablation", category: .ablation, procedures: [
                ProcedureTag(id: "ep-abl-pvi", title: "Pulmonary Vein Isolation"),
                ProcedureTag(id: "ep-abl-pwi", title: "Posterior Wall Isolation"),
                ProcedureTag(id: "ep-abl-nonpv", title: "Non-Pulmonary Vein Trigger Ablation"),
                ProcedureTag(id: "ep-abl-vom", title: "Vein of Marshall / Alcohol Ablation"),
                ProcedureTag(id: "ep-abl-cti", title: "Typical Atrial Flutter CTI"),
                ProcedureTag(id: "ep-abl-atyp-flutter", title: "Atypical Atrial Flutter"),
                ProcedureTag(id: "ep-abl-avj", title: "AV Junction Ablation"),
                ProcedureTag(id: "ep-abl-svt", title: "SVT Ablation"),
                ProcedureTag(id: "ep-abl-avnrt", title: "AVNRT Ablation"),
                ProcedureTag(id: "ep-abl-focal-at", title: "Focal Atrial Tachycardia"),
                ProcedureTag(id: "ep-abl-avrt", title: "AVRT"),
                ProcedureTag(id: "ep-abl-vt-idio", title: "VT/PVC (Idiopathic)"),
                ProcedureTag(id: "ep-abl-vt-struct", title: "VT/PVC (Structural)")
            ]),
            PackCategory(id: "ep-device", category: .implants, procedures: [
                ProcedureTag(id: "ep-dev-ppm-sp", title: "Single Chamber Pacemaker"),
                ProcedureTag(id: "ep-dev-ppm-dp", title: "Dual Chamber Pacemaker"),
                ProcedureTag(id: "ep-dev-crt-p", title: "CRT-P"),
                ProcedureTag(id: "ep-dev-crt-d", title: "CRT-D"),
                ProcedureTag(id: "ep-dev-icd", title: "ICD"),
                ProcedureTag(id: "ep-dev-sicd", title: "SubQ ICD"),
                ProcedureTag(id: "ep-dev-evicd", title: "Extravasc ICD"),
                ProcedureTag(id: "ep-dev-leadless", title: "Leadless Pacemaker"),
                ProcedureTag(id: "ep-dev-his", title: "His Bundle/LBBP"),
                ProcedureTag(id: "ep-dev-ppm-gen", title: "PPM Generator Change"),
                ProcedureTag(id: "ep-dev-icd-gen", title: "ICD Generator Change"),
                ProcedureTag(id: "ep-dev-transvenous", title: "Transvenous Pacemaker"),
                ProcedureTag(id: "ep-dev-extract", title: "Lead Extraction"),
                ProcedureTag(id: "ep-dev-lead-rev", title: "Lead Revision"),
                ProcedureTag(id: "ep-dev-laao", title: "LAAO"),
                ProcedureTag(id: "ep-dev-ilr", title: "ILR"),
                ProcedureTag(id: "ep-dev-ccm", title: "CCM")
            ])
        ],
        defaultAccessSites: [.femoral, .subclavian, .axillary, .jugular, .pericardial, .transseptal],
        defaultComplications: [.bleeding, .vascular, .tamponade, .pneumothorax, .stroke, .death]
    )
    
    // MARK: - Cardiac Imaging
    
    static let cardiacImaging = SpecialtyPack(
        id: "cardiac-imaging",
        name: "Cardiac Imaging",
        shortName: "CI",
        type: .fellowship,
        categories: [
            PackCategory(id: "ci-echo", category: .echo, procedures: [
                ProcedureTag(id: "ci-echo-tte", title: "TTE"),
                ProcedureTag(id: "ci-echo-tte-contrast", title: "TTE with Contrast"),
                ProcedureTag(id: "ci-echo-stress", title: "Stress Echo"),
                ProcedureTag(id: "ci-echo-tee", title: "TEE")
            ]),
            PackCategory(id: "ci-nuclear", category: .nuclear, procedures: [
                ProcedureTag(id: "ci-nuc-spect", title: "SPECT"),
                ProcedureTag(id: "ci-nuc-pet", title: "PET"),
                ProcedureTag(id: "ci-nuc-pet-ct", title: "PET/CT"),
                ProcedureTag(id: "ci-nuc-muga", title: "MUGA")
            ]),
            PackCategory(id: "ci-ct", category: .cardiacCT, procedures: [
                ProcedureTag(id: "ci-ct-calcium", title: "Calcium Score"),
                ProcedureTag(id: "ci-ct-cta", title: "Coronary CTA"),
                ProcedureTag(id: "ci-ct-cardiac", title: "Cardiac CT")
            ]),
            PackCategory(id: "ci-mri", category: .cardiacMRI, procedures: [
                ProcedureTag(id: "ci-mri-cardiac", title: "Cardiac MRI")
            ]),
            PackCategory(id: "ci-vasc-us", category: .vascularUltrasound, procedures: [
                ProcedureTag(id: "ci-vasc-carotid", title: "Carotid Doppler"),
                ProcedureTag(id: "ci-vasc-le-art", title: "Lower Extremity Arterial"),
                ProcedureTag(id: "ci-vasc-le-ven", title: "Lower Extremity Venous"),
                ProcedureTag(id: "ci-vasc-ue-art", title: "Upper Extremity Arterial"),
                ProcedureTag(id: "ci-vasc-ue-ven", title: "Upper Extremity Venous"),
                ProcedureTag(id: "ci-vasc-aaa", title: "Abdominal Aortic")
            ])
        ],
        defaultAccessSites: [],
        defaultComplications: [.allergicReaction, .arrhythmia, .hypotension]
    )
    
    // MARK: - Gastroenterology
    
    static let gastroenterology = SpecialtyPack(
        id: "gastroenterology",
        name: "Gastroenterology",
        shortName: "GI",
        type: .fellowship,
        categories: [
            PackCategory(id: "gi-upper", category: .upperGI, procedures: [
                ProcedureTag(id: "gi-upper-egd", title: "EGD"),
                ProcedureTag(id: "gi-upper-biopsy", title: "Upper GI Biopsy"),
                ProcedureTag(id: "gi-upper-dilat", title: "Esophageal Dilation"),
                ProcedureTag(id: "gi-upper-stent", title: "Esophageal Stent"),
                ProcedureTag(id: "gi-upper-varix", title: "Variceal Banding"),
                ProcedureTag(id: "gi-upper-peg", title: "PEG Placement"),
                ProcedureTag(id: "gi-upper-hemostasis", title: "Upper GI Hemostasis"),
                ProcedureTag(id: "gi-upper-emr", title: "EMR"),
                ProcedureTag(id: "gi-upper-esd", title: "ESD"),
                ProcedureTag(id: "gi-upper-poem", title: "POEM")
            ]),
            PackCategory(id: "gi-lower", category: .lowerGI, procedures: [
                ProcedureTag(id: "gi-lower-colo", title: "Colonoscopy"),
                ProcedureTag(id: "gi-lower-flex", title: "Flexible Sigmoidoscopy"),
                ProcedureTag(id: "gi-lower-polypectomy", title: "Polypectomy"),
                ProcedureTag(id: "gi-lower-emr", title: "Colonic EMR"),
                ProcedureTag(id: "gi-lower-stent", title: "Colonic Stent"),
                ProcedureTag(id: "gi-lower-hemostasis", title: "Lower GI Hemostasis")
            ]),
            PackCategory(id: "gi-hb", category: .hepatobiliary, procedures: [
                ProcedureTag(id: "gi-hb-ercp", title: "ERCP"),
                ProcedureTag(id: "gi-hb-sphincter", title: "Sphincterotomy"),
                ProcedureTag(id: "gi-hb-stone", title: "Stone Extraction"),
                ProcedureTag(id: "gi-hb-stent", title: "Biliary Stent"),
                ProcedureTag(id: "gi-hb-eus", title: "EUS"),
                ProcedureTag(id: "gi-hb-eus-fna", title: "EUS-FNA/FNB"),
                ProcedureTag(id: "gi-hb-liver-bx", title: "Liver Biopsy"),
                ProcedureTag(id: "gi-hb-paracentesis", title: "Paracentesis")
            ])
        ],
        defaultAccessSites: [.oral, .transanal, .percutaneous],
        defaultComplications: [.bleeding, .perforation, .aspiration, .infection, .death]
    )
    
    // MARK: - Pulmonary/Critical Care
    
    static let pulmonaryCriticalCare = SpecialtyPack(
        id: "pulmonary-critical-care",
        name: "Pulmonary & Critical Care",
        shortName: "PCCM",
        type: .fellowship,
        categories: [
            PackCategory(id: "pccm-bronch", category: .bronchoscopy, procedures: [
                ProcedureTag(id: "pccm-bronch-flex", title: "Flexible Bronchoscopy"),
                ProcedureTag(id: "pccm-bronch-bal", title: "BAL"),
                ProcedureTag(id: "pccm-bronch-biopsy", title: "Transbronchial Biopsy"),
                ProcedureTag(id: "pccm-bronch-ebus", title: "EBUS-TBNA"),
                ProcedureTag(id: "pccm-bronch-nav", title: "Navigational Bronchoscopy"),
                ProcedureTag(id: "pccm-bronch-rigid", title: "Rigid Bronchoscopy"),
                ProcedureTag(id: "pccm-bronch-stent", title: "Airway Stent")
            ]),
            PackCategory(id: "pccm-pleural", category: .thoracic, procedures: [
                ProcedureTag(id: "pccm-pleural-thoracentesis", title: "Thoracentesis"),
                ProcedureTag(id: "pccm-pleural-chest-tube", title: "Chest Tube"),
                ProcedureTag(id: "pccm-pleural-pleurx", title: "PleurX Catheter"),
                ProcedureTag(id: "pccm-pleural-pleurodesis", title: "Pleurodesis"),
                ProcedureTag(id: "pccm-pleural-thoracoscopy", title: "Medical Thoracoscopy")
            ]),
            PackCategory(id: "pccm-airway", category: .airway, procedures: [
                ProcedureTag(id: "pccm-airway-intub", title: "Endotracheal Intubation"),
                ProcedureTag(id: "pccm-airway-diff", title: "Difficult Airway Management"),
                ProcedureTag(id: "pccm-airway-trach", title: "Percutaneous Tracheostomy")
            ]),
            PackCategory(id: "pccm-icu", category: .bedside, procedures: [
                ProcedureTag(id: "pccm-icu-aline", title: "Arterial Line"),
                ProcedureTag(id: "pccm-icu-cvl", title: "Central Venous Catheter"),
                ProcedureTag(id: "pccm-icu-pa-cath", title: "PA Catheter"),
                ProcedureTag(id: "pccm-icu-dialysis-cath", title: "Dialysis Catheter"),
                ProcedureTag(id: "pccm-icu-pericardio", title: "Pericardiocentesis")
            ])
        ],
        defaultAccessSites: [.oral, .nasal, .jugular, .subclavian, .femoral],
        defaultComplications: [.bleeding, .pneumothorax, .hypotension, .arrhythmia, .infection, .death]
    )
    
    // MARK: - Nephrology
    
    static let nephrology = SpecialtyPack(
        id: "nephrology",
        name: "Nephrology",
        shortName: "Neph",
        type: .fellowship,
        categories: [
            PackCategory(id: "neph-access", category: .vascularAccess, procedures: [
                ProcedureTag(id: "neph-access-temp", title: "Temporary Dialysis Catheter"),
                ProcedureTag(id: "neph-access-perm", title: "Tunneled Dialysis Catheter")
            ]),
            PackCategory(id: "neph-dialysis", category: .dialysis, procedures: [
                ProcedureTag(id: "neph-dial-hd", title: "Hemodialysis Initiation"),
                ProcedureTag(id: "neph-dial-pd", title: "Peritoneal Dialysis"),
                ProcedureTag(id: "neph-dial-crrt", title: "CRRT")
            ]),
            PackCategory(id: "neph-biopsy", category: .biopsy, procedures: [
                ProcedureTag(id: "neph-bx-native", title: "Native Kidney Biopsy"),
                ProcedureTag(id: "neph-bx-transplant", title: "Transplant Kidney Biopsy")
            ])
        ],
        defaultAccessSites: [.jugular, .femoral, .subclavian, .percutaneous],
        defaultComplications: [.bleeding, .infection, .pneumothorax, .hypotension, .death]
    )
    
    // MARK: - General Surgery
    
    static let generalSurgery = SpecialtyPack(
        id: "general-surgery",
        name: "General Surgery",
        shortName: "GenSurg",
        type: .residency,
        categories: [
            PackCategory(id: "gs-lap", category: .laparoscopic, procedures: [
                ProcedureTag(id: "gs-lap-chole", title: "Laparoscopic Cholecystectomy"),
                ProcedureTag(id: "gs-lap-appy", title: "Laparoscopic Appendectomy"),
                ProcedureTag(id: "gs-lap-hernia-ing", title: "Lap Inguinal Hernia Repair"),
                ProcedureTag(id: "gs-lap-hernia-vent", title: "Lap Ventral Hernia Repair"),
                ProcedureTag(id: "gs-lap-nissen", title: "Lap Nissen Fundoplication"),
                ProcedureTag(id: "gs-lap-colectomy", title: "Lap Colectomy"),
                ProcedureTag(id: "gs-lap-splenectomy", title: "Lap Splenectomy"),
                ProcedureTag(id: "gs-lap-gastric", title: "Lap Sleeve/Bypass")
            ]),
            PackCategory(id: "gs-open", category: .open, procedures: [
                ProcedureTag(id: "gs-open-chole", title: "Open Cholecystectomy"),
                ProcedureTag(id: "gs-open-appy", title: "Open Appendectomy"),
                ProcedureTag(id: "gs-open-hernia", title: "Open Hernia Repair"),
                ProcedureTag(id: "gs-open-colectomy", title: "Open Colectomy"),
                ProcedureTag(id: "gs-open-sb-resect", title: "Small Bowel Resection"),
                ProcedureTag(id: "gs-open-gastrectomy", title: "Gastrectomy"),
                ProcedureTag(id: "gs-open-whipple", title: "Whipple"),
                ProcedureTag(id: "gs-open-hepatectomy", title: "Hepatectomy"),
                ProcedureTag(id: "gs-open-thyroid", title: "Thyroidectomy"),
                ProcedureTag(id: "gs-open-mastectomy", title: "Mastectomy")
            ]),
            PackCategory(id: "gs-emergent", category: .emergent, procedures: [
                ProcedureTag(id: "gs-em-ex-lap", title: "Exploratory Laparotomy"),
                ProcedureTag(id: "gs-em-damage", title: "Damage Control Laparotomy"),
                ProcedureTag(id: "gs-em-lysis", title: "Lysis of Adhesions"),
                ProcedureTag(id: "gs-em-ostomy", title: "Ostomy Creation"),
                ProcedureTag(id: "gs-em-debride", title: "Wound Debridement")
            ]),
            PackCategory(id: "gs-endo", category: .endoscopic, procedures: [
                ProcedureTag(id: "gs-endo-egd", title: "EGD"),
                ProcedureTag(id: "gs-endo-colo", title: "Colonoscopy")
            ]),
            PackCategory(id: "gs-bedside", category: .bedside, procedures: [
                ProcedureTag(id: "gs-bed-cvl", title: "Central Line"),
                ProcedureTag(id: "gs-bed-aline", title: "Arterial Line"),
                ProcedureTag(id: "gs-bed-chest-tube", title: "Chest Tube"),
                ProcedureTag(id: "gs-bed-trach", title: "Tracheostomy")
            ])
        ],
        defaultAccessSites: [.laparoscopicPort, .openIncision, .oral, .transanal],
        defaultComplications: [.bleeding, .infection, .anastomoticLeak, .woundDehiscence, .dvtPe, .ileus, .death]
    )
    
    // MARK: - Orthopedic Surgery
    
    static let orthopedicSurgery = SpecialtyPack(
        id: "orthopedic-surgery",
        name: "Orthopedic Surgery",
        shortName: "Ortho",
        type: .residency,
        categories: [
            PackCategory(id: "ortho-trauma", category: .fractureCare, procedures: [
                ProcedureTag(id: "ortho-fx-closed", title: "Closed Reduction"),
                ProcedureTag(id: "ortho-fx-orif-hip", title: "ORIF Hip/Femur"),
                ProcedureTag(id: "ortho-fx-orif-tibia", title: "ORIF Tibia/Ankle"),
                ProcedureTag(id: "ortho-fx-orif-humerus", title: "ORIF Humerus"),
                ProcedureTag(id: "ortho-fx-orif-radius", title: "ORIF Radius/Ulna"),
                ProcedureTag(id: "ortho-fx-im-nail", title: "Intramedullary Nailing"),
                ProcedureTag(id: "ortho-fx-ex-fix", title: "External Fixation")
            ]),
            PackCategory(id: "ortho-joint", category: .jointArthroscopy, procedures: [
                ProcedureTag(id: "ortho-scope-knee-menisc", title: "Meniscectomy/Repair"),
                ProcedureTag(id: "ortho-scope-knee-acl", title: "ACL Reconstruction"),
                ProcedureTag(id: "ortho-scope-shoulder-rc", title: "Rotator Cuff Repair"),
                ProcedureTag(id: "ortho-scope-shoulder-bank", title: "Bankart Repair"),
                ProcedureTag(id: "ortho-scope-hip", title: "Hip Arthroscopy")
            ]),
            PackCategory(id: "ortho-arthro", category: .arthroplasty, procedures: [
                ProcedureTag(id: "ortho-tka", title: "Total Knee Arthroplasty"),
                ProcedureTag(id: "ortho-tha", title: "Total Hip Arthroplasty"),
                ProcedureTag(id: "ortho-hemi", title: "Hip Hemiarthroplasty"),
                ProcedureTag(id: "ortho-tsa", title: "Total Shoulder Arthroplasty"),
                ProcedureTag(id: "ortho-rsa", title: "Reverse Shoulder Arthroplasty")
            ]),
            PackCategory(id: "ortho-spine", category: .spinal, procedures: [
                ProcedureTag(id: "ortho-spine-discectomy", title: "Discectomy"),
                ProcedureTag(id: "ortho-spine-lami", title: "Laminectomy"),
                ProcedureTag(id: "ortho-spine-fusion", title: "Spinal Fusion")
            ]),
            PackCategory(id: "ortho-soft", category: .softTissue, procedures: [
                ProcedureTag(id: "ortho-soft-ctr", title: "Carpal Tunnel Release"),
                ProcedureTag(id: "ortho-soft-trigger", title: "Trigger Finger Release"),
                ProcedureTag(id: "ortho-soft-achilles", title: "Achilles Repair")
            ])
        ],
        defaultAccessSites: [.openIncision, .percutaneous, .laparoscopicPort],
        defaultComplications: [.bleeding, .infection, .nerveInjury, .dvtPe, .compartmentSyndrome, .death]
    )
    
    // MARK: - Emergency Medicine
    
    static let emergencyMedicine = SpecialtyPack(
        id: "emergency-medicine",
        name: "Emergency Medicine",
        shortName: "EM",
        type: .residency,
        categories: [
            PackCategory(id: "em-airway", category: .airway, procedures: [
                ProcedureTag(id: "em-airway-intub", title: "Endotracheal Intubation"),
                ProcedureTag(id: "em-airway-rsi", title: "RSI"),
                ProcedureTag(id: "em-airway-video", title: "Video Laryngoscopy"),
                ProcedureTag(id: "em-airway-sga", title: "Supraglottic Airway"),
                ProcedureTag(id: "em-airway-cric", title: "Cricothyrotomy")
            ]),
            PackCategory(id: "em-resus", category: .resuscitation, procedures: [
                ProcedureTag(id: "em-resus-cpr", title: "CPR"),
                ProcedureTag(id: "em-resus-defib", title: "Defibrillation"),
                ProcedureTag(id: "em-resus-cardio", title: "Synchronized Cardioversion"),
                ProcedureTag(id: "em-resus-pacing", title: "Transcutaneous Pacing"),
                ProcedureTag(id: "em-resus-thor", title: "Resuscitative Thoracotomy")
            ]),
            PackCategory(id: "em-vascular", category: .vascularAccess, procedures: [
                ProcedureTag(id: "em-vas-piv", title: "Peripheral IV"),
                ProcedureTag(id: "em-vas-io", title: "Intraosseous Access"),
                ProcedureTag(id: "em-vas-cvl", title: "Central Venous Catheter"),
                ProcedureTag(id: "em-vas-aline", title: "Arterial Line")
            ]),
            PackCategory(id: "em-thoracic", category: .thoracic, procedures: [
                ProcedureTag(id: "em-thor-chest-tube", title: "Chest Tube/Thoracostomy"),
                ProcedureTag(id: "em-thor-needle", title: "Needle Decompression"),
                ProcedureTag(id: "em-thor-pericardio", title: "Pericardiocentesis")
            ]),
            PackCategory(id: "em-trauma", category: .trauma, procedures: [
                ProcedureTag(id: "em-trauma-fast", title: "FAST Exam"),
                ProcedureTag(id: "em-trauma-lac", title: "Laceration Repair"),
                ProcedureTag(id: "em-trauma-fracture", title: "Fracture Reduction/Splinting"),
                ProcedureTag(id: "em-trauma-disloc", title: "Joint Reduction")
            ]),
            PackCategory(id: "em-bedside", category: .bedside, procedures: [
                ProcedureTag(id: "em-bed-lp", title: "Lumbar Puncture"),
                ProcedureTag(id: "em-bed-paracentesis", title: "Paracentesis"),
                ProcedureTag(id: "em-bed-abscess", title: "Abscess I&D"),
                ProcedureTag(id: "em-bed-arthrocentesis", title: "Arthrocentesis")
            ]),
            PackCategory(id: "em-regional", category: .regional, procedures: [
                ProcedureTag(id: "em-reg-digital", title: "Digital Block"),
                ProcedureTag(id: "em-reg-hematoma", title: "Hematoma Block"),
                ProcedureTag(id: "em-reg-fascia", title: "Fascia Iliaca Block")
            ]),
            PackCategory(id: "em-us", category: .imagingGuided, procedures: [
                ProcedureTag(id: "em-us-cardiac", title: "Cardiac POCUS"),
                ProcedureTag(id: "em-us-lung", title: "Lung Ultrasound"),
                ProcedureTag(id: "em-us-dvt", title: "DVT Ultrasound"),
                ProcedureTag(id: "em-us-efast", title: "Extended FAST")
            ])
        ],
        defaultAccessSites: [.femoral, .jugular, .subclavian, .radial, .oral, .nasal],
        defaultComplications: [.bleeding, .pneumothorax, .infection, .aspiration, .cardiacArrest, .death]
    )
    
    // MARK: - Anesthesiology
    
    static let anesthesiology = SpecialtyPack(
        id: "anesthesiology",
        name: "Anesthesiology",
        shortName: "Anes",
        type: .residency,
        categories: [
            PackCategory(id: "anes-airway", category: .airway, procedures: [
                ProcedureTag(id: "anes-airway-mask", title: "Mask Ventilation"),
                ProcedureTag(id: "anes-airway-intub-dl", title: "Direct Laryngoscopy"),
                ProcedureTag(id: "anes-airway-intub-vl", title: "Video Laryngoscopy"),
                ProcedureTag(id: "anes-airway-sga", title: "Supraglottic Airway"),
                ProcedureTag(id: "anes-airway-fiberoptic", title: "Fiberoptic Intubation"),
                ProcedureTag(id: "anes-airway-dlt", title: "Double Lumen Tube"),
                ProcedureTag(id: "anes-airway-awake", title: "Awake Intubation")
            ]),
            PackCategory(id: "anes-neuraxial", category: .neuraxial, procedures: [
                ProcedureTag(id: "anes-nax-spinal", title: "Spinal Anesthesia"),
                ProcedureTag(id: "anes-nax-epidural", title: "Epidural Placement"),
                ProcedureTag(id: "anes-nax-cse", title: "Combined Spinal-Epidural"),
                ProcedureTag(id: "anes-nax-labor", title: "Labor Epidural")
            ]),
            PackCategory(id: "anes-regional", category: .regional, procedures: [
                ProcedureTag(id: "anes-reg-interscalene", title: "Interscalene Block"),
                ProcedureTag(id: "anes-reg-supraclav", title: "Supraclavicular Block"),
                ProcedureTag(id: "anes-reg-axillary", title: "Axillary Block"),
                ProcedureTag(id: "anes-reg-femoral", title: "Femoral Nerve Block"),
                ProcedureTag(id: "anes-reg-adductor", title: "Adductor Canal Block"),
                ProcedureTag(id: "anes-reg-sciatic", title: "Sciatic Block"),
                ProcedureTag(id: "anes-reg-popliteal", title: "Popliteal Block"),
                ProcedureTag(id: "anes-reg-tap", title: "TAP Block"),
                ProcedureTag(id: "anes-reg-esp", title: "Erector Spinae Block"),
                ProcedureTag(id: "anes-reg-pecs", title: "PECS Block")
            ]),
            PackCategory(id: "anes-vascular", category: .vascularAccess, procedures: [
                ProcedureTag(id: "anes-vas-piv", title: "Peripheral IV"),
                ProcedureTag(id: "anes-vas-cvl", title: "Central Line"),
                ProcedureTag(id: "anes-vas-aline", title: "Arterial Line"),
                ProcedureTag(id: "anes-vas-pa-cath", title: "PA Catheter")
            ]),
            PackCategory(id: "anes-sedation", category: .sedation, procedures: [
                ProcedureTag(id: "anes-sed-mac", title: "MAC/Sedation"),
                ProcedureTag(id: "anes-sed-general", title: "General Anesthesia"),
                ProcedureTag(id: "anes-sed-tiva", title: "TIVA")
            ]),
            PackCategory(id: "anes-cardiac", category: .mcs, procedures: [
                ProcedureTag(id: "anes-card-cpb", title: "CPB Management"),
                ProcedureTag(id: "anes-card-tee", title: "TEE")
            ])
        ],
        defaultAccessSites: [.oral, .nasal, .jugular, .subclavian, .femoral, .radial],
        defaultComplications: [.airwayCompromise, .aspiration, .hypotension, .arrhythmia, .pneumothorax, .nerveInjury, .death]
    )
    
    // MARK: - OB/GYN
    
    static let obgyn = SpecialtyPack(
        id: "obgyn",
        name: "Obstetrics & Gynecology",
        shortName: "OB/GYN",
        type: .residency,
        categories: [
            PackCategory(id: "obgyn-ob", category: .obstetric, procedures: [
                ProcedureTag(id: "obgyn-ob-svd", title: "Spontaneous Vaginal Delivery"),
                ProcedureTag(id: "obgyn-ob-vacuum", title: "Vacuum-Assisted Delivery"),
                ProcedureTag(id: "obgyn-ob-forceps", title: "Forceps Delivery"),
                ProcedureTag(id: "obgyn-ob-cs", title: "Cesarean Section"),
                ProcedureTag(id: "obgyn-ob-lac-repair", title: "Laceration Repair"),
                ProcedureTag(id: "obgyn-ob-cerclage", title: "Cervical Cerclage"),
                ProcedureTag(id: "obgyn-ob-amnio", title: "Amniocentesis"),
                ProcedureTag(id: "obgyn-ob-btl", title: "Postpartum BTL")
            ]),
            PackCategory(id: "obgyn-gyn-lap", category: .laparoscopic, procedures: [
                ProcedureTag(id: "obgyn-lap-dx", title: "Diagnostic Laparoscopy"),
                ProcedureTag(id: "obgyn-lap-tlh", title: "TLH"),
                ProcedureTag(id: "obgyn-lap-myomectomy", title: "Lap Myomectomy"),
                ProcedureTag(id: "obgyn-lap-cystectomy", title: "Lap Ovarian Cystectomy"),
                ProcedureTag(id: "obgyn-lap-salpingectomy", title: "Lap Salpingectomy"),
                ProcedureTag(id: "obgyn-lap-btl", title: "Lap BTL"),
                ProcedureTag(id: "obgyn-lap-endo", title: "Endometriosis Excision")
            ]),
            PackCategory(id: "obgyn-gyn-open", category: .open, procedures: [
                ProcedureTag(id: "obgyn-open-tah", title: "TAH"),
                ProcedureTag(id: "obgyn-open-tah-bso", title: "TAH-BSO"),
                ProcedureTag(id: "obgyn-open-myomectomy", title: "Abdominal Myomectomy")
            ]),
            PackCategory(id: "obgyn-gyn-vag", category: .gynecologic, procedures: [
                ProcedureTag(id: "obgyn-vag-tvh", title: "TVH"),
                ProcedureTag(id: "obgyn-vag-hysteroscopy", title: "Hysteroscopy"),
                ProcedureTag(id: "obgyn-vag-dnc", title: "D&C"),
                ProcedureTag(id: "obgyn-vag-dne", title: "D&E"),
                ProcedureTag(id: "obgyn-vag-polypectomy", title: "Hysteroscopic Polypectomy"),
                ProcedureTag(id: "obgyn-vag-ablation", title: "Endometrial Ablation"),
                ProcedureTag(id: "obgyn-vag-leep", title: "LEEP"),
                ProcedureTag(id: "obgyn-vag-colposcopy", title: "Colposcopy"),
                ProcedureTag(id: "obgyn-vag-iud", title: "IUD Placement/Removal")
            ])
        ],
        defaultAccessSites: [.transvaginal, .laparoscopicPort, .openIncision],
        defaultComplications: [.bleeding, .infection, .perforation, .urinaryRetention, .dvtPe, .death]
    )
    
    // MARK: - Neurosurgery
    
    static let neurosurgery = SpecialtyPack(
        id: "neurosurgery",
        name: "Neurosurgery",
        shortName: "NSG",
        type: .residency,
        categories: [
            PackCategory(id: "nsg-cranial", category: .cranial, procedures: [
                ProcedureTag(id: "nsg-cranial-crani", title: "Craniotomy"),
                ProcedureTag(id: "nsg-cranial-tumor", title: "Brain Tumor Resection"),
                ProcedureTag(id: "nsg-cranial-evd", title: "EVD Placement"),
                ProcedureTag(id: "nsg-cranial-shunt", title: "VP Shunt"),
                ProcedureTag(id: "nsg-cranial-dbs", title: "Deep Brain Stimulation"),
                ProcedureTag(id: "nsg-cranial-hematoma", title: "Hematoma Evacuation"),
                ProcedureTag(id: "nsg-cranial-aneurysm", title: "Aneurysm Clipping")
            ]),
            PackCategory(id: "nsg-spine", category: .spinal, procedures: [
                ProcedureTag(id: "nsg-spine-discectomy", title: "Discectomy"),
                ProcedureTag(id: "nsg-spine-lami", title: "Laminectomy"),
                ProcedureTag(id: "nsg-spine-acdf", title: "ACDF"),
                ProcedureTag(id: "nsg-spine-fusion", title: "Posterior Fusion"),
                ProcedureTag(id: "nsg-spine-tumor", title: "Spinal Tumor Resection")
            ])
        ],
        defaultAccessSites: [.openIncision, .percutaneous],
        defaultComplications: [.bleeding, .infection, .stroke, .nerveInjury, .death]
    )
    
    // MARK: - Cardiothoracic Surgery
    
    static let cardiothoracicSurgery = SpecialtyPack(
        id: "cardiothoracic-surgery",
        name: "Cardiothoracic Surgery",
        shortName: "CT Surg",
        type: .residency,
        categories: [
            PackCategory(id: "cts-cardiac", category: .open, procedures: [
                ProcedureTag(id: "cts-cardiac-cabg", title: "CABG"),
                ProcedureTag(id: "cts-cardiac-avr", title: "Aortic Valve Replacement"),
                ProcedureTag(id: "cts-cardiac-mvr", title: "Mitral Valve Repair/Replace"),
                ProcedureTag(id: "cts-cardiac-aortic", title: "Aortic Surgery"),
                ProcedureTag(id: "cts-cardiac-transplant", title: "Heart Transplant"),
                ProcedureTag(id: "cts-cardiac-lvad", title: "LVAD Implant")
            ]),
            PackCategory(id: "cts-thoracic", category: .thoracic, procedures: [
                ProcedureTag(id: "cts-thor-lobectomy", title: "Lobectomy"),
                ProcedureTag(id: "cts-thor-pneumonectomy", title: "Pneumonectomy"),
                ProcedureTag(id: "cts-thor-wedge", title: "Wedge Resection"),
                ProcedureTag(id: "cts-thor-esophagectomy", title: "Esophagectomy"),
                ProcedureTag(id: "cts-thor-vats", title: "VATS")
            ]),
            PackCategory(id: "cts-mcs", category: .mcs, procedures: [
                ProcedureTag(id: "cts-mcs-ecmo", title: "ECMO Cannulation"),
                ProcedureTag(id: "cts-mcs-iabp", title: "IABP")
            ])
        ],
        defaultAccessSites: [.openIncision, .femoral, .axillary],
        defaultComplications: [.bleeding, .stroke, .arrhythmia, .infection, .respiratoryFailure, .death]
    )
    
    // MARK: - Vascular Surgery
    
    static let vascularSurgery = SpecialtyPack(
        id: "vascular-surgery",
        name: "Vascular Surgery",
        shortName: "Vasc Surg",
        type: .residency,
        categories: [
            PackCategory(id: "vasc-open", category: .open, procedures: [
                ProcedureTag(id: "vasc-open-cea", title: "Carotid Endarterectomy"),
                ProcedureTag(id: "vasc-open-aaa", title: "Open AAA Repair"),
                ProcedureTag(id: "vasc-open-bypass", title: "Bypass Surgery"),
                ProcedureTag(id: "vasc-open-embolectomy", title: "Embolectomy"),
                ProcedureTag(id: "vasc-open-avf", title: "AV Fistula Creation")
            ]),
            PackCategory(id: "vasc-endo", category: .therapeutic, procedures: [
                ProcedureTag(id: "vasc-endo-evar", title: "EVAR"),
                ProcedureTag(id: "vasc-endo-tevar", title: "TEVAR"),
                ProcedureTag(id: "vasc-endo-cas", title: "Carotid Stent"),
                ProcedureTag(id: "vasc-endo-peripheral", title: "Peripheral Intervention"),
                ProcedureTag(id: "vasc-endo-atherectomy", title: "Atherectomy"),
                ProcedureTag(id: "vasc-endo-ivc", title: "IVC Filter")
            ])
        ],
        defaultAccessSites: [.femoral, .radial, .brachial, .openIncision],
        defaultComplications: [.bleeding, .vascular, .stroke, .infection, .death]
    )
    
    // MARK: - Plastic Surgery
    
    static let plasticSurgery = SpecialtyPack(
        id: "plastic-surgery",
        name: "Plastic Surgery",
        shortName: "Plastics",
        type: .residency,
        categories: [
            PackCategory(id: "prs-reconstructive", category: .reconstructive, procedures: [
                ProcedureTag(id: "prs-recon-flap-local", title: "Local Flap"),
                ProcedureTag(id: "prs-recon-flap-free", title: "Free Flap"),
                ProcedureTag(id: "prs-recon-breast", title: "Breast Reconstruction"),
                ProcedureTag(id: "prs-recon-skin-graft", title: "Skin Graft")
            ]),
            PackCategory(id: "prs-hand", category: .softTissue, procedures: [
                ProcedureTag(id: "prs-hand-tendon", title: "Tendon Repair"),
                ProcedureTag(id: "prs-hand-nerve", title: "Nerve Repair"),
                ProcedureTag(id: "prs-hand-ctr", title: "Carpal Tunnel Release"),
                ProcedureTag(id: "prs-hand-replant", title: "Digit Replantation")
            ]),
            PackCategory(id: "prs-aesthetic", category: .aesthetic, procedures: [
                ProcedureTag(id: "prs-aes-rhino", title: "Rhinoplasty"),
                ProcedureTag(id: "prs-aes-bleph", title: "Blepharoplasty"),
                ProcedureTag(id: "prs-aes-facelift", title: "Facelift"),
                ProcedureTag(id: "prs-aes-breast-aug", title: "Breast Augmentation"),
                ProcedureTag(id: "prs-aes-abdominoplasty", title: "Abdominoplasty"),
                ProcedureTag(id: "prs-aes-lipo", title: "Liposuction")
            ])
        ],
        defaultAccessSites: [.openIncision, .percutaneous],
        defaultComplications: [.bleeding, .infection, .hematoma, .seroma, .woundDehiscence, .nerveInjury]
    )
    
    // MARK: - Urology
    
    static let urology = SpecialtyPack(
        id: "urology",
        name: "Urology",
        shortName: "Uro",
        type: .residency,
        categories: [
            PackCategory(id: "uro-endo", category: .endourology, procedures: [
                ProcedureTag(id: "uro-endo-cysto", title: "Cystoscopy"),
                ProcedureTag(id: "uro-endo-turbt", title: "TURBT"),
                ProcedureTag(id: "uro-endo-turp", title: "TURP"),
                ProcedureTag(id: "uro-endo-ureteroscopy", title: "Ureteroscopy"),
                ProcedureTag(id: "uro-endo-laser-litho", title: "Laser Lithotripsy"),
                ProcedureTag(id: "uro-endo-pcnl", title: "PCNL"),
                ProcedureTag(id: "uro-endo-stent", title: "Ureteral Stent")
            ]),
            PackCategory(id: "uro-open", category: .open, procedures: [
                ProcedureTag(id: "uro-open-nephrectomy", title: "Nephrectomy"),
                ProcedureTag(id: "uro-open-partial-neph", title: "Partial Nephrectomy"),
                ProcedureTag(id: "uro-open-cystectomy", title: "Radical Cystectomy"),
                ProcedureTag(id: "uro-open-prostatectomy", title: "Radical Prostatectomy")
            ]),
            PackCategory(id: "uro-robotic", category: .robotic, procedures: [
                ProcedureTag(id: "uro-rob-prostatectomy", title: "Robotic Prostatectomy"),
                ProcedureTag(id: "uro-rob-partial-neph", title: "Robotic Partial Nephrectomy"),
                ProcedureTag(id: "uro-rob-cystectomy", title: "Robotic Cystectomy")
            ]),
            PackCategory(id: "uro-andro", category: .andrology, procedures: [
                ProcedureTag(id: "uro-andro-vasectomy", title: "Vasectomy"),
                ProcedureTag(id: "uro-andro-penile-implant", title: "Penile Prosthesis"),
                ProcedureTag(id: "uro-andro-hydrocele", title: "Hydrocelectomy")
            ])
        ],
        defaultAccessSites: [.transvaginal, .percutaneous, .openIncision, .roboticPort],
        defaultComplications: [.bleeding, .infection, .urinaryRetention, .death]
    )
    
    // MARK: - ENT
    
    static let entOtolaryngology = SpecialtyPack(
        id: "ent-otolaryngology",
        name: "Otolaryngology - Head & Neck",
        shortName: "ENT",
        type: .residency,
        categories: [
            PackCategory(id: "ent-otology", category: .otology, procedures: [
                ProcedureTag(id: "ent-oto-tube", title: "Myringotomy/Tubes"),
                ProcedureTag(id: "ent-oto-tympano", title: "Tympanoplasty"),
                ProcedureTag(id: "ent-oto-mastoid", title: "Mastoidectomy"),
                ProcedureTag(id: "ent-oto-cochlear", title: "Cochlear Implant")
            ]),
            PackCategory(id: "ent-rhino", category: .rhinology, procedures: [
                ProcedureTag(id: "ent-rhino-septoplasty", title: "Septoplasty"),
                ProcedureTag(id: "ent-rhino-fess", title: "FESS"),
                ProcedureTag(id: "ent-rhino-balloon", title: "Balloon Sinuplasty")
            ]),
            PackCategory(id: "ent-laryngo", category: .laryngology, procedures: [
                ProcedureTag(id: "ent-laryngo-dls", title: "Direct Laryngoscopy"),
                ProcedureTag(id: "ent-laryngo-microlaryngo", title: "Microlaryngoscopy"),
                ProcedureTag(id: "ent-laryngo-trach", title: "Tracheostomy")
            ]),
            PackCategory(id: "ent-head-neck", category: .headNeck, procedures: [
                ProcedureTag(id: "ent-hn-thyroidectomy", title: "Thyroidectomy"),
                ProcedureTag(id: "ent-hn-parotidectomy", title: "Parotidectomy"),
                ProcedureTag(id: "ent-hn-neck-dissection", title: "Neck Dissection"),
                ProcedureTag(id: "ent-hn-ta", title: "Tonsillectomy/Adenoidectomy")
            ])
        ],
        defaultAccessSites: [.oral, .nasal, .openIncision],
        defaultComplications: [.bleeding, .infection, .nerveInjury, .airwayCompromise, .hematoma]
    )
    
    // MARK: - Ophthalmology
    
    static let ophthalmology = SpecialtyPack(
        id: "ophthalmology",
        name: "Ophthalmology",
        shortName: "Ophtho",
        type: .residency,
        categories: [
            PackCategory(id: "ophtho-anterior", category: .anterior, procedures: [
                ProcedureTag(id: "ophtho-ant-phaco", title: "Phacoemulsification/IOL"),
                ProcedureTag(id: "ophtho-ant-corneal-transplant", title: "Corneal Transplant")
            ]),
            PackCategory(id: "ophtho-glaucoma", category: .glaucoma, procedures: [
                ProcedureTag(id: "ophtho-glauc-trabeculectomy", title: "Trabeculectomy"),
                ProcedureTag(id: "ophtho-glauc-tube", title: "Tube Shunt"),
                ProcedureTag(id: "ophtho-glauc-migs", title: "MIGS")
            ]),
            PackCategory(id: "ophtho-retina", category: .posterior, procedures: [
                ProcedureTag(id: "ophtho-ret-ppv", title: "Pars Plana Vitrectomy"),
                ProcedureTag(id: "ophtho-ret-scleral-buckle", title: "Scleral Buckle"),
                ProcedureTag(id: "ophtho-ret-injection", title: "Intravitreal Injection")
            ]),
            PackCategory(id: "ophtho-oculoplastic", category: .oculoplastic, procedures: [
                ProcedureTag(id: "ophtho-oculo-bleph", title: "Blepharoplasty"),
                ProcedureTag(id: "ophtho-oculo-ptosis", title: "Ptosis Repair"),
                ProcedureTag(id: "ophtho-oculo-dcr", title: "DCR")
            ])
        ],
        defaultAccessSites: [.percutaneous],
        defaultComplications: [.bleeding, .infection, .other]
    )
    
    // MARK: - Internal Medicine
    
    static let internalMedicine = SpecialtyPack(
        id: "internal-medicine",
        name: "Internal Medicine",
        shortName: "IM",
        type: .residency,
        categories: [
            PackCategory(id: "im-procedures", category: .bedside, procedures: [
                ProcedureTag(id: "im-aline", title: "Arterial Line", subOptions: ["Femoral", "Radial"]),
                ProcedureTag(id: "im-cvl", title: "Central Venous Catheter", subOptions: ["Jugular", "Subclavian", "Femoral"]),
                ProcedureTag(id: "im-lp", title: "Lumbar Puncture"),
                ProcedureTag(id: "im-paracentesis", title: "Paracentesis"),
                ProcedureTag(id: "im-thoracentesis", title: "Thoracentesis"),
                ProcedureTag(id: "im-arthrocentesis", title: "Arthrocentesis", subOptions: ["Knee", "Elbow"], allowsCustomSubOption: true),
                ProcedureTag(id: "im-intubation", title: "Endotracheal Intubation")
            ])
        ],
        defaultAccessSites: [.femoral, .jugular, .subclavian, .radial],
        defaultComplications: [.bleeding, .infection, .pneumothorax, .arterialPuncture, .hematoma]
    )
    
    // MARK: - Family Medicine
    
    static let familyMedicine = SpecialtyPack(
        id: "family-medicine",
        name: "Family Medicine",
        shortName: "FM",
        type: .residency,
        categories: [
            PackCategory(id: "fm-office", category: .bedside, procedures: [
                ProcedureTag(id: "fm-lac", title: "Laceration Repair"),
                ProcedureTag(id: "fm-abscess", title: "Abscess I&D"),
                ProcedureTag(id: "fm-skin-biopsy", title: "Skin Biopsy"),
                ProcedureTag(id: "fm-joint-inject", title: "Joint Injection"),
                ProcedureTag(id: "fm-iud", title: "IUD Insertion/Removal"),
                ProcedureTag(id: "fm-implant", title: "Nexplanon Insertion/Removal"),
                ProcedureTag(id: "fm-pap", title: "Pap Smear"),
                ProcedureTag(id: "fm-colposcopy", title: "Colposcopy"),
                ProcedureTag(id: "fm-vasectomy", title: "Vasectomy"),
                ProcedureTag(id: "fm-toenail", title: "Ingrown Toenail Removal")
            ]),
            PackCategory(id: "fm-ob", category: .obstetric, procedures: [
                ProcedureTag(id: "fm-svd", title: "Spontaneous Vaginal Delivery"),
                ProcedureTag(id: "fm-circumcision", title: "Newborn Circumcision")
            ])
        ],
        defaultAccessSites: [.percutaneous, .transvaginal],
        defaultComplications: [.bleeding, .infection]
    )
    
    // MARK: - Pediatrics
    
    static let pediatrics = SpecialtyPack(
        id: "pediatrics",
        name: "Pediatrics",
        shortName: "Peds",
        type: .residency,
        categories: [
            PackCategory(id: "peds-procedures", category: .pediatric, procedures: [
                ProcedureTag(id: "peds-lp", title: "Lumbar Puncture"),
                ProcedureTag(id: "peds-iv", title: "Peripheral IV"),
                ProcedureTag(id: "peds-lac", title: "Laceration Repair"),
                ProcedureTag(id: "peds-abscess", title: "Abscess I&D"),
                ProcedureTag(id: "peds-splint", title: "Splinting"),
                ProcedureTag(id: "peds-circumcision", title: "Circumcision"),
                ProcedureTag(id: "peds-bladder-cath", title: "Bladder Catheterization")
            ])
        ],
        defaultAccessSites: [.percutaneous],
        defaultComplications: [.bleeding, .infection]
    )
    
    // MARK: - Dermatology
    
    static let dermatology = SpecialtyPack(
        id: "dermatology",
        name: "Dermatology",
        shortName: "Derm",
        type: .residency,
        categories: [
            PackCategory(id: "derm-procedures", category: .biopsy, procedures: [
                ProcedureTag(id: "derm-shave-bx", title: "Shave Biopsy"),
                ProcedureTag(id: "derm-punch-bx", title: "Punch Biopsy"),
                ProcedureTag(id: "derm-excisional-bx", title: "Excisional Biopsy"),
                ProcedureTag(id: "derm-ed-c", title: "Electrodesiccation & Curettage"),
                ProcedureTag(id: "derm-cryo", title: "Cryotherapy"),
                ProcedureTag(id: "derm-excision", title: "Excision with Closure"),
                ProcedureTag(id: "derm-mohs", title: "Mohs Surgery"),
                ProcedureTag(id: "derm-flap", title: "Local Flap"),
                ProcedureTag(id: "derm-laser", title: "Laser Therapy"),
                ProcedureTag(id: "derm-botox", title: "Botulinum Toxin"),
                ProcedureTag(id: "derm-filler", title: "Dermal Filler")
            ])
        ],
        defaultAccessSites: [.percutaneous],
        defaultComplications: [.bleeding, .infection, .other]
    )
    
    // MARK: - Pain Medicine
    
    static let painMedicine = SpecialtyPack(
        id: "pain-medicine",
        name: "Pain Medicine",
        shortName: "Pain",
        type: .fellowship,
        categories: [
            PackCategory(id: "pain-spine", category: .spinal, procedures: [
                ProcedureTag(id: "pain-spine-esi", title: "Epidural Steroid Injection"),
                ProcedureTag(id: "pain-spine-tfesi", title: "Transforaminal ESI"),
                ProcedureTag(id: "pain-spine-facet", title: "Facet Joint Injection"),
                ProcedureTag(id: "pain-spine-mbb", title: "Medial Branch Block"),
                ProcedureTag(id: "pain-spine-rfa", title: "Facet RFA"),
                ProcedureTag(id: "pain-spine-si", title: "SI Joint Injection")
            ]),
            PackCategory(id: "pain-neuro", category: .therapeutic, procedures: [
                ProcedureTag(id: "pain-neuro-scs", title: "Spinal Cord Stimulator"),
                ProcedureTag(id: "pain-neuro-pump", title: "Intrathecal Pump")
            ]),
            PackCategory(id: "pain-block", category: .regional, procedures: [
                ProcedureTag(id: "pain-block-stellate", title: "Stellate Ganglion Block"),
                ProcedureTag(id: "pain-block-celiac", title: "Celiac Plexus Block"),
                ProcedureTag(id: "pain-block-lumbar-symp", title: "Lumbar Sympathetic Block"),
                ProcedureTag(id: "pain-block-intercostal", title: "Intercostal Nerve Block")
            ]),
            PackCategory(id: "pain-joint", category: .injection, procedures: [
                ProcedureTag(id: "pain-joint-knee", title: "Knee Injection"),
                ProcedureTag(id: "pain-joint-hip", title: "Hip Injection"),
                ProcedureTag(id: "pain-joint-shoulder", title: "Shoulder Injection"),
                ProcedureTag(id: "pain-joint-trigger", title: "Trigger Point Injection")
            ])
        ],
        defaultAccessSites: [.percutaneous],
        defaultComplications: [.bleeding, .infection, .nerveInjury, .pneumothorax, .hypotension]
    )
    
    // MARK: - Interventional Radiology
    
    static let interventionalRadiology = SpecialtyPack(
        id: "interventional-radiology",
        name: "Interventional Radiology",
        shortName: "IR",
        type: .fellowship,
        categories: [
            PackCategory(id: "ir-vascular", category: .therapeutic, procedures: [
                ProcedureTag(id: "ir-vasc-angio", title: "Diagnostic Angiography"),
                ProcedureTag(id: "ir-vasc-angioplasty", title: "Angioplasty"),
                ProcedureTag(id: "ir-vasc-stent", title: "Vascular Stent"),
                ProcedureTag(id: "ir-vasc-embo", title: "Embolization"),
                ProcedureTag(id: "ir-vasc-thrombolysis", title: "Thrombolysis"),
                ProcedureTag(id: "ir-vasc-ivc", title: "IVC Filter"),
                ProcedureTag(id: "ir-vasc-tips", title: "TIPS")
            ]),
            PackCategory(id: "ir-nonvasc", category: .imagingGuided, procedures: [
                ProcedureTag(id: "ir-nv-biopsy", title: "Image-Guided Biopsy"),
                ProcedureTag(id: "ir-nv-drain", title: "Abscess/Collection Drainage"),
                ProcedureTag(id: "ir-nv-nephrostomy", title: "Nephrostomy"),
                ProcedureTag(id: "ir-nv-gastrostomy", title: "Gastrostomy"),
                ProcedureTag(id: "ir-nv-biliary", title: "Biliary Drainage"),
                ProcedureTag(id: "ir-nv-chest-tube", title: "Chest Tube"),
                ProcedureTag(id: "ir-nv-port", title: "Port Placement")
            ]),
            PackCategory(id: "ir-ablation", category: .ablation, procedures: [
                ProcedureTag(id: "ir-abl-rfa", title: "RFA Tumor Ablation"),
                ProcedureTag(id: "ir-abl-mwa", title: "Microwave Ablation"),
                ProcedureTag(id: "ir-abl-cryo", title: "Cryoablation"),
                ProcedureTag(id: "ir-abl-y90", title: "Y90 Radioembolization"),
                ProcedureTag(id: "ir-abl-tace", title: "TACE")
            ]),
            PackCategory(id: "ir-spine", category: .spinal, procedures: [
                ProcedureTag(id: "ir-spine-vertebro", title: "Vertebroplasty"),
                ProcedureTag(id: "ir-spine-kypho", title: "Kyphoplasty")
            ])
        ],
        defaultAccessSites: [.femoral, .radial, .jugular, .percutaneous],
        defaultComplications: [.bleeding, .vascular, .infection, .perforation, .death]
    )
}
