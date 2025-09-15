;; Conservation Fund Contract
;; A decentralized fund for conservation projects with governance and transparency

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-PROJECT-INACTIVE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-VOTING-CLOSED (err u106))
(define-constant ERR-UNAUTHORIZED (err u107))
(define-constant ERR-INVALID-INPUT (err u108))

;; Data Variables
(define-data-var total-fund uint u0)
(define-data-var project-counter uint u0)
(define-data-var min-donation uint u1000000) ;; 1 STX minimum
(define-data-var voting-period uint u1440) ;; blocks (~10 days)

;; Data Maps
(define-map contributors principal uint)
(define-map projects uint {
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    creator: principal,
    active: bool,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    funded: bool
})
(define-map project-votes {project-id: uint, voter: principal} bool)
(define-map project-donations {project-id: uint, donor: principal} uint)

;; Input validation functions
(define-private (is-valid-string (input (string-ascii 100)))
    (and (> (len input) u0) (<= (len input) u100)))

(define-private (is-valid-description (input (string-ascii 500)))
    (and (> (len input) u0) (<= (len input) u500)))

(define-private (is-valid-uint (input uint))
    (and (> input u0) (<= input u340282366920938463463374607431768211455)))

(define-private (is-valid-project-id (project-id uint))
    (and (> project-id u0) (<= project-id (var-get project-counter))))

;; Read-only functions
(define-read-only (get-total-fund)
    (var-get total-fund))

(define-read-only (get-contributor-amount (contributor principal))
    (default-to u0 (map-get? contributors contributor)))

(define-read-only (get-project (project-id uint))
    (map-get? projects project-id))

(define-read-only (get-project-count)
    (var-get project-counter))

(define-read-only (has-voted (project-id uint) (voter principal))
    (is-some (map-get? project-votes {project-id: project-id, voter: voter})))

(define-read-only (get-donation-amount (project-id uint) (donor principal))
    (default-to u0 (map-get? project-donations {project-id: project-id, donor: donor})))

(define-read-only (get-voting-power (contributor principal))
    (let ((contribution (get-contributor-amount contributor)))
        (if (>= contribution u10000000) ;; 10 STX for voting rights
            (/ contribution u1000000)
            u0)))

;; Public functions
(define-public (donate-to-fund (amount uint))
    (begin
        (asserts! (>= amount (var-get min-donation)) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-fund (+ (var-get total-fund) amount))
        (map-set contributors tx-sender 
            (+ (get-contributor-amount tx-sender) amount))
        (print {event: "donation", donor: tx-sender, amount: amount})
        (ok true)))

(define-public (create-project (title (string-ascii 100)) 
                              (description (string-ascii 500)) 
                              (funding-goal uint))
    (let ((project-id (+ (var-get project-counter) u1)))
        ;; Added input validation to fix warnings
        (asserts! (is-valid-string title) ERR-INVALID-INPUT)
        (asserts! (is-valid-description description) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint funding-goal) ERR-INVALID-AMOUNT)
        (asserts! (>= (get-contributor-amount tx-sender) u5000000) ERR-UNAUTHORIZED) ;; 5 STX to create
        (map-set projects project-id {
            title: title,
            description: description,
            funding-goal: funding-goal,
            current-funding: u0,
            creator: tx-sender,
            active: true,
            votes-for: u0,
            votes-against: u0,
            voting-deadline: (+ block-height (var-get voting-period)),
            funded: false
        })
        (var-set project-counter project-id)
        (print {event: "project-created", project-id: project-id, creator: tx-sender})
        (ok project-id)))

(define-public (vote-on-project (project-id uint) (vote-for bool))
    (let ((project (unwrap! (get-project project-id) ERR-NOT-FOUND))
          (voting-power (get-voting-power tx-sender)))
        (asserts! (> voting-power u0) ERR-UNAUTHORIZED)
        (asserts! (get active project) ERR-PROJECT-INACTIVE)
        (asserts! (<= block-height (get voting-deadline project)) ERR-VOTING-CLOSED)
        (asserts! (not (has-voted project-id tx-sender)) ERR-ALREADY-VOTED)
        
        (map-set project-votes {project-id: project-id, voter: tx-sender} true)
        (map-set projects project-id 
            (merge project {
                votes-for: (if vote-for 
                    (+ (get votes-for project) voting-power)
                    (get votes-for project)),
                votes-against: (if vote-for 
                    (get votes-against project)
                    (+ (get votes-against project) voting-power))
            }))
        (print {event: "vote-cast", project-id: project-id, voter: tx-sender, vote-for: vote-for})
        (ok true)))

(define-public (fund-project (project-id uint))
    (let ((project (unwrap! (get-project project-id) ERR-NOT-FOUND)))
        (asserts! (get active project) ERR-PROJECT-INACTIVE)
        (asserts! (> block-height (get voting-deadline project)) ERR-VOTING-CLOSED)
        (asserts! (> (get votes-for project) (get votes-against project)) ERR-UNAUTHORIZED)
        (asserts! (not (get funded project)) ERR-PROJECT-INACTIVE)
        (asserts! (>= (var-get total-fund) (get funding-goal project)) ERR-INSUFFICIENT-FUNDS)
        
        (try! (as-contract (stx-transfer? (get funding-goal project) tx-sender (get creator project))))
        (var-set total-fund (- (var-get total-fund) (get funding-goal project)))
        (map-set projects project-id (merge project {funded: true, active: false}))
        (print {event: "project-funded", project-id: project-id, amount: (get funding-goal project)})
        (ok true)))

(define-public (donate-to-project (project-id uint) (amount uint))
    (let ((project (unwrap! (get-project project-id) ERR-NOT-FOUND)))
        (asserts! (get active project) ERR-PROJECT-INACTIVE)
        (asserts! (>= amount (var-get min-donation)) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set project-donations {project-id: project-id, donor: tx-sender}
            (+ (get-donation-amount project-id tx-sender) amount))
        (map-set projects project-id 
            (merge project {current-funding: (+ (get current-funding project) amount)}))
        (print {event: "project-donation", project-id: project-id, donor: tx-sender, amount: amount})
        (ok true)))

(define-public (withdraw-project-funds (project-id uint))
    (let ((project (unwrap! (get-project project-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get creator project)) ERR-UNAUTHORIZED)
        (asserts! (>= (get current-funding project) (get funding-goal project)) ERR-INSUFFICIENT-FUNDS)
        (asserts! (not (get funded project)) ERR-PROJECT-INACTIVE)
        
        (try! (as-contract (stx-transfer? (get current-funding project) tx-sender (get creator project))))
        (map-set projects project-id (merge project {funded: true, active: false}))
        (print {event: "project-withdrawn", project-id: project-id, amount: (get current-funding project)})
        (ok true)))

;; Admin functions
(define-public (set-min-donation (new-min uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        ;; Added input validation for new-min parameter
        (asserts! (is-valid-uint new-min) ERR-INVALID-INPUT)
        (var-set min-donation new-min)
        (ok true)))

(define-public (set-voting-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        ;; Added input validation for new-period parameter
        (asserts! (is-valid-uint new-period) ERR-INVALID-INPUT)
        (var-set voting-period new-period)
        (ok true)))

(define-public (deactivate-project (project-id uint))
    (let ((project (unwrap! (get-project project-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        ;; Added input validation for project-id parameter
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (map-set projects project-id (merge project {active: false}))
        (print {event: "project-deactivated", project-id: project-id})
        (ok true)))

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (<= amount (var-get total-fund)) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (var-set total-fund (- (var-get total-fund) amount))
        (print {event: "emergency-withdrawal", amount: amount})
        (ok true)))

;; Initialize contract
(begin
    (print {event: "contract-deployed", owner: CONTRACT-OWNER})
    (ok true))
