<?php

class Setting {
    private $db;
    private $table = 'settings';

    public function __construct($db) {
        $this->db = $db;
    }

    /**
     * Get all settings in a specific group
     * 
     * @param string $group
     * @return array
     */
    public function getByGroup($group = 'payment') {
        $stmt = $this->db->prepare("SELECT setting_key, setting_value FROM " . $this->table . " WHERE group_name = ?");
        $stmt->execute([$group]);
        
        $results = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $results[$row['setting_key']] = $row['setting_value'];
        }
        
        return $results;
    }

    /**
     * Get a single setting by key
     * 
     * @param string $key
     * @return string|null
     */
    public function getByKey($key) {
        $stmt = $this->db->prepare("SELECT setting_value FROM " . $this->table . " WHERE setting_key = ? LIMIT 1");
        $stmt->execute([$key]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $row ? $row['setting_value'] : null;
    }
}
?>
