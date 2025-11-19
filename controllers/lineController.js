import Line from '../models/Line.js';
import { v4 as uuidv4 } from 'uuid';


export const getAllLines = async (req, res, next) => {
  try {
    const { active } = req.query;
    const filters = {};
    
    if (active !== undefined) {
      filters.active = active === 'true';
    }
    
    const lines = await Line.findAll(filters);
    res.json(lines);
  } catch (error) {
    next(error);
  }
};


export const getActiveLines = async (req, res, next) => {
  try {
    const lines = await Line.getActiveLines();
    res.json(lines);
  } catch (error) {
    next(error);
  }
};


export const getLineById = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    const line = await Line.findById(lineid);
    
    if (!line) {
      return res.status(404).json({ 
        message: req.t('line.not_found') || 'Line not found' 
      });
    }
    
    res.json(line);
  } catch (error) {
    next(error);
  }
};


export const createLine = async (req, res, next) => {
  try {
    const { linename, baseprice, additionalprice, estduration, distance } = req.body;
    
    const lineData = {
      lineid: uuidv4(),
      linename,
      baseprice,
      additionalprice: additionalprice || 0,
      estduration,
      distance,
      active: true,
    };
    
    const line = await Line.create(lineData);
    res.status(201).json({
      message: req.t('line.created') || 'Line created successfully',
      line,
    });
  } catch (error) {
    next(error);
  }
};


export const updateLine = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    const updates = req.body;
    
    const line = await Line.update(lineid, updates);
    res.json({
      message: req.t('line.updated') || 'Line updated successfully',
      line,
    });
  } catch (error) {
    next(error);
  }
};


export const deleteLine = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    
    
    await Line.update(lineid, { active: false });
    
    res.json({
      message: req.t('line.deleted') || 'Line deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

