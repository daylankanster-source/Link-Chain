// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title LinkChain — on-chain permanent link registry with stake-to-boost ranking
contract LinkChain is Ownable, ReentrancyGuard, Pausable {
    struct Link {
        uint256 id;
        address owner;
        string slug;          // human-readable identifier, unique
        string url;           // full URL
        string title;         // display title
        uint256 createdAt;
        uint256 totalBoost;   // cumulative BOT staked for boosts (weighted)
        uint256 lastBoostAt;
    }

    struct Boost {
        address booster;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 public registrationFee = 0.01 ether;     // one-time fee to register a link
    uint256 public platformFeeBps = 500;             // 5% of every boost goes to platform
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant DECAY_HALF_LIFE = 7 days; // boost weight halves every 7 days

    uint256 public linkCount;
    uint256 public feesCollected;

    mapping(uint256 => Link) public links;
    mapping(string => uint256) public slugToId;           // slug => id (0 = not taken)
    mapping(uint256 => Boost[]) public boostHistory;      // linkId => boosts
    mapping(address => uint256[]) public linksByOwner;

    event LinkRegistered(uint256 indexed id, address indexed owner, string slug, string url);
    event LinkBoosted(uint256 indexed id, address indexed booster, uint256 amount, uint256 newTotalBoost);
    event LinkUpdated(uint256 indexed id, string newUrl, string newTitle);
    event FeesWithdrawn(address indexed to, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // ---------- Core actions ----------

    function registerLink(string calldata slug, string calldata url, string calldata title)
        external payable whenNotPaused nonReentrant returns (uint256)
    {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(slug).length > 0 && bytes(slug).length <= 32, "Slug 1-32 chars");
        require(bytes(url).length > 0 && bytes(url).length <= 512, "URL 1-512 chars");
        require(bytes(title).length <= 128, "Title max 128");
        require(slugToId[slug] == 0, "Slug already taken");

        linkCount++;
        uint256 id = linkCount;

        links[id] = Link({
            id: id,
            owner: msg.sender,
            slug: slug,
            url: url,
            title: title,
            createdAt: block.timestamp,
            totalBoost: 0,
            lastBoostAt: 0
        });
        slugToId[slug] = id;
        linksByOwner[msg.sender].push(id);

        feesCollected += msg.value;
        emit LinkRegistered(id, msg.sender, slug, url);
        return id;
    }

    function boostLink(uint256 id) external payable whenNotPaused nonReentrant {
        require(id > 0 && id <= linkCount, "Invalid link");
        require(msg.value > 0, "Must send BOT");

        uint256 fee = (msg.value * platformFeeBps) / BPS_DENOM;
        uint256 net = msg.value - fee;
        feesCollected += fee;

        Link storage L = links[id];
        L.totalBoost += net;
        L.lastBoostAt = block.timestamp;

        boostHistory[id].push(Boost({
            booster: msg.sender,
            amount: net,
            timestamp: block.timestamp
        }));

        // reward flows to link owner as tip
        (bool ok, ) = payable(L.owner).call{value: net}("");
        require(ok, "Owner transfer failed");

        emit LinkBoosted(id, msg.sender, net, L.totalBoost);
    }

    function updateLink(uint256 id, string calldata newUrl, string calldata newTitle) external {
        require(id > 0 && id <= linkCount, "Invalid link");
        Link storage L = links[id];
        require(msg.sender == L.owner, "Not owner");
        require(bytes(newUrl).length > 0 && bytes(newUrl).length <= 512, "URL 1-512 chars");
        require(bytes(newTitle).length <= 128, "Title max 128");
        L.url = newUrl;
        L.title = newTitle;
        emit LinkUpdated(id, newUrl, newTitle);
    }

    // ---------- Views ----------

    function getLink(uint256 id) external view returns (Link memory) {
        require(id > 0 && id <= linkCount, "Invalid link");
        return links[id];
    }

    function resolveSlug(string calldata slug) external view returns (Link memory) {
        uint256 id = slugToId[slug];
        require(id != 0, "Not found");
        return links[id];
    }

    function getBoostCount(uint256 id) external view returns (uint256) {
        return boostHistory[id].length;
    }

    function getLinksByOwner(address who) external view returns (uint256[] memory) {
        return linksByOwner[who];
    }

    /// @notice Decayed weight: totalBoost * 0.5^(age/halfLife)  — approximated linearly per half-life bucket
    function currentWeight(uint256 id) public view returns (uint256) {
        Link memory L = links[id];
        if (L.lastBoostAt == 0 || L.totalBoost == 0) return 0;
        uint256 age = block.timestamp - L.lastBoostAt;
        uint256 halfLives = age / DECAY_HALF_LIFE;
        if (halfLives >= 10) return 0;
        uint256 w = L.totalBoost;
        for (uint256 i = 0; i < halfLives; i++) { w /= 2; }
        return w;
    }

    function getRecent(uint256 limit) external view returns (Link[] memory) {
        if (limit > linkCount) limit = linkCount;
        Link[] memory out = new Link[](limit);
        for (uint256 i = 0; i < limit; i++) {
            out[i] = links[linkCount - i];
        }
        return out;
    }

    // ---------- Admin ----------

    function setRegistrationFee(uint256 v) external onlyOwner { registrationFee = v; }
    function setPlatformFeeBps(uint256 v) external onlyOwner { require(v <= 2000, "Max 20%"); platformFeeBps = v; }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        uint256 amt = feesCollected;
        feesCollected = 0;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "Withdraw failed");
        emit FeesWithdrawn(to, amt);
    }

    receive() external payable { feesCollected += msg.value; }
}
