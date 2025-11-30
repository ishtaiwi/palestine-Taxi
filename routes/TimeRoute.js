import express from 'express';
import { DateTime } from 'luxon';
const router = express.Router();

router.get('/', (req, res) => {
    const currentTime = DateTime.local();
    console.log(`*************************************************Current server time requested: ${currentTime}`);
    res.json({ time: currentTime });

});

export default router;